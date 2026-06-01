using System;
using System.IO;
using Microsoft.Data.Sqlite;
using Xunit;
using PSSqliteRoH.Sqlite;

namespace PSSqliteRoH.Sqlite.Tests
{
    // This class contains automated checks to make sure the helper methods work correctly.
    // Each method below is a small scenario that tests one behavior of the code.
    public class SqliteDatabaseManagerTests : IDisposable
    {
        private readonly string _tempDirectory;

        // This constructor runs before each test.
        // It creates a fresh temporary folder to store database files during testing.
        public SqliteDatabaseManagerTests()
        {
            _tempDirectory = Path.Combine(Path.GetTempPath(), "PSSqliteRoH.Tests", Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(_tempDirectory);
        }

        [Fact]
        public void BuildConnectionString_CreatesDirectory_WhenCreateIfNotExistsIsTrue()
        {
            // Arrange: choose a file path inside a folder that does not exist yet.
            string filePath = Path.Combine(_tempDirectory, "subdir", "test.db");

            // Act: ask the manager to build a connection string and create the folder if needed.
            string connectionString = SqliteDatabaseManager.BuildConnectionString(filePath, createIfNotExists: true, readOnly: false);

            // Assert: the returned text should include the database location and the correct mode.
            Assert.Contains("Data Source=", connectionString, StringComparison.OrdinalIgnoreCase);
            Assert.Contains("Mode=ReadWriteCreate", connectionString, StringComparison.OrdinalIgnoreCase);
            // Assert: the helper should have created the folder.
            Assert.True(Directory.Exists(Path.GetDirectoryName(filePath)));
        }

        [Fact]
        public void BuildConnectionString_ThrowsFileNotFound_WhenDatabaseMissingAndCreateIsFalse()
        {
            // Arrange: choose a database file path that does not exist.
            string filePath = Path.Combine(_tempDirectory, "missing.db");

            // Act & Assert: building a connection string without permission to create the file should fail.
            Assert.Throws<FileNotFoundException>(() => SqliteDatabaseManager.BuildConnectionString(filePath, createIfNotExists: false, readOnly: false));
        }

        [Fact]
        public void CreateConnection_ThrowsArgumentException_WhenConnectionStringIsEmpty()
        {
            // Act & Assert: passing an empty connection string should produce a clear error.
            Assert.Throws<ArgumentException>(() => SqliteDatabaseManager.CreateConnection(string.Empty));
        }

        [Fact]
        public void CreateConnection_ReturnsOpenableConnection_WhenConnectionStringIsValid()
        {
            // Arrange: build a valid connection string for a new database file.
            string filePath = Path.Combine(_tempDirectory, "test2.db");
            string connectionString = SqliteDatabaseManager.BuildConnectionString(filePath, createIfNotExists: true, readOnly: false);

            // Act: create the connection and open it.
            using var connection = SqliteDatabaseManager.CreateConnection(connectionString);
            connection.Open();

            // Assert: opening the connection should succeed and the state should be open.
            Assert.Equal(System.Data.ConnectionState.Open, connection.State);
        }

        // This method runs after each test and cleans up the temporary folder.
        public void Dispose()
        {
            if (Directory.Exists(_tempDirectory))
            {
                Directory.Delete(_tempDirectory, recursive: true);
            }
        }
    }
}
