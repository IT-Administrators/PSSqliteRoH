using System;
using System.IO;
using Microsoft.Data.Sqlite;
using Xunit;
using PSSqliteRoH.Sqlite;

namespace PSSqliteRoH.Sqlite.Tests
{
    public class SqliteDatabaseManagerTests : IDisposable
    {
        private readonly string _tempDirectory;

        public SqliteDatabaseManagerTests()
        {
            _tempDirectory = Path.Combine(Path.GetTempPath(), "PSSqliteRoH.Tests", Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(_tempDirectory);
        }

        [Fact]
        public void BuildConnectionString_CreatesDirectory_WhenCreateIfNotExistsIsTrue()
        {
            string filePath = Path.Combine(_tempDirectory, "subdir", "test.db");

            string connectionString = SqliteDatabaseManager.BuildConnectionString(filePath, createIfNotExists: true, readOnly: false);

            Assert.Contains("Data Source=", connectionString, StringComparison.OrdinalIgnoreCase);
            Assert.Contains("Mode=ReadWriteCreate", connectionString, StringComparison.OrdinalIgnoreCase);
            Assert.True(Directory.Exists(Path.GetDirectoryName(filePath)));
        }

        [Fact]
        public void BuildConnectionString_ThrowsFileNotFound_WhenDatabaseMissingAndCreateIsFalse()
        {
            string filePath = Path.Combine(_tempDirectory, "missing.db");

            Assert.Throws<FileNotFoundException>(() => SqliteDatabaseManager.BuildConnectionString(filePath, createIfNotExists: false, readOnly: false));
        }

        [Fact]
        public void CreateConnection_ThrowsArgumentException_WhenConnectionStringIsEmpty()
        {
            Assert.Throws<ArgumentException>(() => SqliteDatabaseManager.CreateConnection(string.Empty));
        }

        [Fact]
        public void CreateConnection_ReturnsOpenableConnection_WhenConnectionStringIsValid()
        {
            string filePath = Path.Combine(_tempDirectory, "test2.db");
            string connectionString = SqliteDatabaseManager.BuildConnectionString(filePath, createIfNotExists: true, readOnly: false);

            using var connection = SqliteDatabaseManager.CreateConnection(connectionString);
            connection.Open();

            Assert.Equal(System.Data.ConnectionState.Open, connection.State);
        }

        public void Dispose()
        {
            if (Directory.Exists(_tempDirectory))
            {
                Directory.Delete(_tempDirectory, recursive: true);
            }
        }
    }
}
