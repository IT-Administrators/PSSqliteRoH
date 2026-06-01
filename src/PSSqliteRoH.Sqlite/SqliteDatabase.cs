using System;
using System.IO;
using Microsoft.Data.Sqlite;
using SQLitePCL;

namespace PSSqliteRoH.Sqlite
{
    // This class contains simple helper methods for working with SQLite databases.
    // It helps build the text needed to open a database file, and it creates the actual connection object.
    public static class SqliteDatabaseManager
    {
        // This block runs once, automatically, before the class is used for the first time.
        static SqliteDatabaseManager()
        {
            try
            {
                // The SQLite library needs a one-time setup step before it can open database files.
                // "Batteries_V2.Init" makes sure the native database engine is ready.
                Batteries_V2.Init();
            }
            catch (Exception ex)
            {
                // If the setup fails, turn the error into a clearer failure message.
                throw new InvalidOperationException($"Failed to initialize the SQLite native provider. {ex}", ex);
            }
        }

        // This method prepares a connection string, which is a text instruction that tells SQLite how to open the file.
        public static string BuildConnectionString(string databasePath, bool createIfNotExists, bool readOnly)
        {
            // If no real file path, stop and explain the problem.
            if (string.IsNullOrWhiteSpace(databasePath))
            {
                throw new ArgumentException("A valid SQLite database path is required.", nameof(databasePath));
            }

            // Convert the path to a full absolute path so the database file location is clear.
            var absolutePath = Path.GetFullPath(databasePath);
            var directory = Path.GetDirectoryName(absolutePath);

            // If folder does not exist.
            if (string.IsNullOrWhiteSpace(directory))
            {
                throw new ArgumentException("Unable to determine the directory for the database path.", nameof(databasePath));
            }

            // If file created but the folder is missing, create the folder now.
            if (createIfNotExists && !Directory.Exists(directory))
            {
                Directory.CreateDirectory(directory);
            }

            // If allowed to create a new file and the file does not exist, throw a clear error.
            if (!createIfNotExists && !File.Exists(absolutePath))
            {
                throw new FileNotFoundException($"SQLite database file not found: {absolutePath}", absolutePath);
            }

            // Build the actual text that SQLite uses to open the database.
            var builder = new SqliteConnectionStringBuilder
            {
                DataSource = absolutePath,
                // Choose the right mode: read-only, create-if-needed, or open existing file.
                Mode = readOnly ? SqliteOpenMode.ReadOnly : (createIfNotExists ? SqliteOpenMode.ReadWriteCreate : SqliteOpenMode.ReadWrite),
                // Shared cache is a typical setting that helps the database work correctly in multiple places.
                Cache = SqliteCacheMode.Shared
            };

            // Return the connection string as a simple text value.
            return builder.ToString();
        }

        // This method creates the connection object itself from the text built earlier.
        public static SqliteConnection CreateConnection(string connectionString)
        {
            // Caller must provide the connection text.
            if (string.IsNullOrWhiteSpace(connectionString))
            {
                throw new ArgumentException("A valid connection string is required.", nameof(connectionString));
            }

            // Create and return the new connection object.
            return new SqliteConnection(connectionString);
        }
    }
}
