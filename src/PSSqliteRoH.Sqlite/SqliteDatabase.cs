using System;
using System.IO;
using Microsoft.Data.Sqlite;
using SQLitePCL;

namespace PSSqliteRoH.Sqlite
{
    /// <summary>
    /// A wrapper around SqliteConnection that enforces read-only mode by setting PRAGMA query_only.
    /// This class is used internally to ensure read-only connections truly prevent writes.
    /// </summary>
    internal class ReadOnlySqliteConnection : SqliteConnection
    {
        private bool _readOnlyPragmaSet = false;

        /// <summary>
        /// Initializes a new read-only SQLite connection wrapper.
        /// </summary>
        /// <param name="connectionString">The connection string to use.</param>
        public ReadOnlySqliteConnection(string connectionString) : base(connectionString)
        {
        }

        /// <summary>
        /// Opens the connection and enforces read-only mode by setting PRAGMA query_only = TRUE.
        /// </summary>
        public override void Open()
        {
            // Open the underlying connection first.
            base.Open();
            
            // Then set the read-only PRAGMA to prevent any writes.
            try
            {
                if (!_readOnlyPragmaSet)
                {
                    using (var command = this.CreateCommand())
                    {
                        command.CommandText = "PRAGMA query_only = TRUE;";
                        command.ExecuteNonQuery();
                    }
                    _readOnlyPragmaSet = true;
                }
            }
            catch (Exception ex)
            {
                // If we can't set the PRAGMA, close the connection and throw a meaningful error.
                this.Close();
                throw new InvalidOperationException("Failed to enforce read-only mode on the SQLite connection.", ex);
            }
        }
    }
    /// <summary>
    /// A helper class that simplifies working with SQLite databases from PowerShell.
    /// 
    /// <para>
    /// SQLiteDatabaseManager provides two core functions:
    /// <list type="number">
    ///   <item>
    ///     <description><see cref="BuildConnectionString"/> - Creates a connection string (a text instruction that tells SQLite how to open a database file)</description>
    ///   </item>
    ///   <item>
    ///     <description><see cref="CreateConnection"/> - Creates an actual database connection object from a connection string</description>
    ///   </item>
    /// </list>
    /// </para>
    /// 
    /// <para>
    /// This class is "static", which means you don't create an instance of it - you just call its methods directly.
    /// Think of it as a toolbox where the tools are always available without needing to build the toolbox first.
    /// </para>
    /// 
    /// <para>
    /// <strong>Note:</strong> The SQLite native library (the actual database engine) is initialized automatically 
    /// the first time this class is used. This happens in the static constructor, which runs once before anything else.
    /// </para>
    /// </summary>
    public static class SqliteDatabaseManager
    {
        /// <summary>
        /// Initializes the SQLite native provider on first use.
        /// 
        /// <para>
        /// This constructor runs automatically and exactly once, before any method in this class is called.
        /// In C#, a "static constructor" is a special method that prepares a static class for use.
        /// </para>
        /// 
        /// <para>
        /// The <c>Batteries_V2.Init()</c> call ensures that the native SQLite database engine is loaded and ready.
        /// SQLite requires this one-time setup before it can open database files.
        /// </para>
        /// </summary>
        /// <exception cref="InvalidOperationException">
        /// Thrown if the SQLite native provider fails to initialize. This usually means there's a problem with 
        /// the SQLite library installation or the system is missing required native libraries.
        /// </exception>
        static SqliteDatabaseManager()
        {
            try
            {
                // Initialize the SQLite native library. This must happen once before using any SQLite functionality.
                Batteries_V2.Init();
            }
            catch (Exception ex)
            {
                // Wrap the underlying error in a more descriptive message for the caller.
                throw new InvalidOperationException($"Failed to initialize the SQLite native provider. {ex}", ex);
            }
        }

        /// <summary>
        /// Builds a connection string that tells SQLite how to open or create a database file.
        /// 
        /// <para>
        /// A connection string is a text value that contains instructions for connecting to a database.
        /// For example: <c>Data Source=/path/to/db.sqlite;Mode=ReadWriteCreate;Cache=Shared</c>
        /// </para>
        /// 
        /// <para>
        /// This method:
        /// <list type="bullet">
        ///   <item><description>Validates that a database path was provided</description></item>
        ///   <item><description>Converts the path to a full absolute path (e.g., <c>/home/user/data/mydb.sqlite</c>)</description></item>
        ///   <item><description>Creates missing directories if <paramref name="createIfNotExists"/> is true</description></item>
        ///   <item><description>Chooses the appropriate SQLite mode based on the parameters</description></item>
        ///   <item><description>Returns a properly formatted connection string</description></item>
        /// </list>
        /// </para>
        /// 
        /// <para>
        /// <strong>Mode Selection:</strong>
        /// <list type="table">
        ///   <listheader><term>Condition</term><description>SQLite Mode Used</description></listheader>
        ///   <item><term><paramref name="readOnly"/> is true</term><description>ReadOnly - Opens the database for reading only, no changes allowed</description></item>
        ///   <item><term><paramref name="createIfNotExists"/> is true</term><description>ReadWriteCreate - Opens the database for reading and writing, creates it if missing</description></item>
        ///   <item><term>Neither flag is true</term><description>ReadWrite - Opens an existing database for reading and writing</description></item>
        /// </list>
        /// </para>
        /// </summary>
        /// <param name="databasePath">
        /// The file path where the SQLite database is located or should be created.
        /// Examples: <c>./mydata.db</c>, <c>/home/user/database.sqlite</c>, or <c>C:\data\test.db</c> on Windows.
        /// Cannot be null or empty.
        /// </param>
        /// <param name="createIfNotExists">
        /// If true, the database file (and its parent directory) will be created if they don't already exist.
        /// If false, an error is thrown if the database file doesn't exist.
        /// </param>
        /// <param name="readOnly">
        /// If true, the database is opened in read-only mode. No INSERT, UPDATE, or DELETE operations are allowed.
        /// If false, the database can be read and written to (assuming <paramref name="createIfNotExists"/> allows it).
        /// </param>
        /// <returns>
        /// A connection string that can be passed to <see cref="CreateConnection"/> to create an actual database connection.
        /// </returns>
        /// <exception cref="ArgumentException">
        /// Thrown if <paramref name="databasePath"/> is null, empty, or contains only whitespace.
        /// Also thrown if the directory cannot be determined from the path.
        /// </exception>
        /// <exception cref="FileNotFoundException">
        /// Thrown if <paramref name="createIfNotExists"/> is false and the database file doesn't exist at the specified path.
        /// </exception>
        public static string BuildConnectionString(string databasePath, bool createIfNotExists, bool readOnly)
        {
            // Validate that the caller provided a real database path.
            if (string.IsNullOrWhiteSpace(databasePath))
            {
                throw new ArgumentException("A valid SQLite database path is required.", nameof(databasePath));
            }

            // Convert to an absolute (full) path. This eliminates ambiguity about where the file is located.
            // For example, "./mydb.db" becomes "/home/user/project/mydb.db"
            var absolutePath = Path.GetFullPath(databasePath);
            var directory = Path.GetDirectoryName(absolutePath);

            // Ensure we successfully extracted the directory from the path.
            if (string.IsNullOrWhiteSpace(directory))
            {
                throw new ArgumentException("Unable to determine the directory for the database path.", nameof(databasePath));
            }

            // If the caller wants us to create the database and the directory doesn't exist, create it now.
            // This prevents errors when trying to create a database in a folder that hasn't been created yet.
            if (createIfNotExists && !Directory.Exists(directory))
            {
                Directory.CreateDirectory(directory);
            }

            // If the caller doesn't want us to create the database, verify the file already exists.
            // Otherwise, throw an error explaining the problem.
            if (!createIfNotExists && !File.Exists(absolutePath))
            {
                throw new FileNotFoundException($"SQLite database file not found: {absolutePath}", absolutePath);
            }

            // Create a builder object that helps construct a properly formatted connection string.
            // Think of SqliteConnectionStringBuilder as a form with fields you fill in, then it creates the final text.
            var builder = new SqliteConnectionStringBuilder
            {
                // Set the path to the database file.
                DataSource = absolutePath,
                
                // Choose how SQLite should open the file:
                // - ReadOnly: No changes allowed, only read operations
                // - ReadWriteCreate: Allow reading and writing, create file if missing
                // - ReadWrite: Allow reading and writing, but file must already exist
                Mode = readOnly ? SqliteOpenMode.ReadOnly : (createIfNotExists ? SqliteOpenMode.ReadWriteCreate : SqliteOpenMode.ReadWrite),
                
                // Cache=Shared is a common setting that allows efficient access to the database
                // from multiple connections. "Shared" means the database cache can be used by multiple connections.
                Cache = SqliteCacheMode.Shared
            };

            // Convert the builder object to a text string and return it.
            return builder.ToString();
        }

        /// <summary>
        /// Creates a SQLite database connection object from a connection string.
        /// 
        /// <para>
        /// A connection object is what you actually use to run SQL commands (queries) against the database.
        /// Before using the connection, it must be opened (usually done automatically by PowerShell cmdlets that use this method).
        /// </para>
        /// 
        /// <para>
        /// <strong>Typical usage flow:</strong>
        /// <list type="number">
        ///   <item><description>Call <see cref="BuildConnectionString"/> to create a connection string</description></item>
        ///   <item><description>Call this method (<see cref="CreateConnection"/>) to create a connection object</description></item>
        ///   <item><description>Open the connection by calling <c>Open()</c> on the returned object</description></item>
        ///   <item><description>Use the connection to run SQL commands</description></item>
        ///   <item><description>Close and dispose of the connection when done</description></item>
        /// </list>
        /// </para>
        /// 
        /// <para>
        /// <strong>Note about Read-Only Mode:</strong>
        /// If the connection string was created with <c>readOnly: true</c> (using <see cref="BuildConnectionString"/>),
        /// this method will return a special wrapper connection that enforces read-only mode by setting the SQLite PRAGMA query_only = TRUE
        /// when the connection is opened. This ensures that write operations (INSERT, UPDATE, DELETE, CREATE TABLE, etc.) will fail with an exception.
        /// </para>
        /// </summary>
        /// <param name="connectionString">
        /// A connection string created by <see cref="BuildConnectionString"/> or manually constructed.
        /// Example: <c>Data Source=/path/to/db.sqlite;Mode=ReadWriteCreate;Cache=Shared</c>
        /// Cannot be null or empty.
        /// </param>
        /// <returns>
        /// A <see cref="SqliteConnection"/> object that can be used to execute SQL commands.
        /// The connection is created but not yet opened. Call the <c>Open()</c> method to open it.
        /// If the connection was created for read-only mode, the <c>Open()</c> call will automatically enforce read-only restrictions.
        /// </returns>
        /// <exception cref="ArgumentException">
        /// Thrown if <paramref name="connectionString"/> is null, empty, or contains only whitespace.
        /// </exception>
        public static SqliteConnection CreateConnection(string connectionString)
        {
            // Validate that the caller provided a real connection string.
            if (string.IsNullOrWhiteSpace(connectionString))
            {
                throw new ArgumentException("A valid connection string is required.", nameof(connectionString));
            }

            // Check if this is a read-only connection by looking for "ReadOnly" in the Mode part of the connection string.
            // If found, return a special wrapper that enforces read-only at the SQLite level.
            if (connectionString.IndexOf("Mode=ReadOnly", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                // Return a read-only wrapper that will set PRAGMA query_only when opened.
                return new ReadOnlySqliteConnection(connectionString);
            }

            // For all other cases, create and return a normal SqliteConnection object.
            return new SqliteConnection(connectionString);
        }
    }
}
