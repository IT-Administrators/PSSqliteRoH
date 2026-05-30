using System;
using System.IO;
using Microsoft.Data.Sqlite;
using SQLitePCL;

namespace PSSqliteRoH.Sqlite
{
    /// <summary>
    /// Provides helper methods to build SQLite connection strings and create connections.
    /// </summary>
    public static class SqliteDatabaseManager
    {
        static SqliteDatabaseManager()
        {
            try
            {
                // Ensure the native SQLite provider is initialized before any connections are created.
                Batteries_V2.Init();
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException($"Failed to initialize the SQLite native provider. {ex}", ex);
            }
        }

        /// <summary>
        /// Builds a SQLite connection string for the provided database path.
        /// </summary>
        /// <param name="databasePath">The SQLite database file path.</param>
        /// <param name="createIfNotExists">Whether to create the file if it does not exist.</param>
        /// <param name="readOnly">Whether to open the database in read-only mode.</param>
        /// <returns>A valid SQLite connection string.</returns>
        public static string BuildConnectionString(string databasePath, bool createIfNotExists, bool readOnly)
        {
            if (string.IsNullOrWhiteSpace(databasePath))
            {
                throw new ArgumentException("A valid SQLite database path is required.", nameof(databasePath));
            }

            var absolutePath = Path.GetFullPath(databasePath);
            var directory = Path.GetDirectoryName(absolutePath);

            if (string.IsNullOrWhiteSpace(directory))
            {
                throw new ArgumentException("Unable to determine the directory for the database path.", nameof(databasePath));
            }

            if (createIfNotExists && !Directory.Exists(directory))
            {
                Directory.CreateDirectory(directory);
            }

            if (!createIfNotExists && !File.Exists(absolutePath))
            {
                throw new FileNotFoundException($"SQLite database file not found: {absolutePath}", absolutePath);
            }

            var builder = new SqliteConnectionStringBuilder
            {
                DataSource = absolutePath,
                Mode = readOnly ? SqliteOpenMode.ReadOnly : (createIfNotExists ? SqliteOpenMode.ReadWriteCreate : SqliteOpenMode.ReadWrite),
                Cache = SqliteCacheMode.Shared
            };

            return builder.ToString();
        }

        /// <summary>
        /// Creates a new SQLite connection instance for the provided connection string.
        /// </summary>
        /// <param name="connectionString">The SQLite connection string.</param>
        /// <returns>A new <see cref="SqliteConnection"/>.</returns>
        public static SqliteConnection CreateConnection(string connectionString)
        {
            if (string.IsNullOrWhiteSpace(connectionString))
            {
                throw new ArgumentException("A valid connection string is required.", nameof(connectionString));
            }

            return new SqliteConnection(connectionString);
        }
    }
}
