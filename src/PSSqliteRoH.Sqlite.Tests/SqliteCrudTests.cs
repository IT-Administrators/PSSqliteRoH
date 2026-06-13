using System;
using System.IO;
using Microsoft.Data.Sqlite;
using Xunit;
using PSSqliteRoH.Sqlite;

namespace PSSqliteRoH.Sqlite.Tests
{
    public class SqliteCrudTests : IDisposable
    {
        private readonly string _tempDirectory;

        public SqliteCrudTests()
        {
            _tempDirectory = Path.Combine(Path.GetTempPath(), "PSSqliteRoH.CrudTests", Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(_tempDirectory);
        }

        [Fact]
        public void CrudOperations_Create_Insert_Select_Update_Delete()
        {
            string filePath = Path.Combine(_tempDirectory, "crud.db");
            string cs = SqliteDatabaseManager.BuildConnectionString(filePath, createIfNotExists: true, readOnly: false);

            using (var connection = SqliteDatabaseManager.CreateConnection(cs))
            {
                connection.Open();

                using var cmd = connection.CreateCommand();

                // Create table
                cmd.CommandText = "CREATE TABLE test_table (id INTEGER PRIMARY KEY, name TEXT);";
                cmd.ExecuteNonQuery();

                // Insert rows
                cmd.CommandText = "INSERT INTO test_table (name) VALUES ('Alice');";
                Assert.Equal(1, cmd.ExecuteNonQuery());

                cmd.CommandText = "INSERT INTO test_table (name) VALUES ('Bob');";
                Assert.Equal(1, cmd.ExecuteNonQuery());

                // Select and verify
                cmd.CommandText = "SELECT COUNT(*) FROM test_table;";
                var count = (long)cmd.ExecuteScalar();
                Assert.Equal(2, count);

                // Update and verify
                cmd.CommandText = "UPDATE test_table SET name = 'Alicia' WHERE name = 'Alice';";
                Assert.Equal(1, cmd.ExecuteNonQuery());

                cmd.CommandText = "SELECT name FROM test_table WHERE id = 1;";
                var name = (string)cmd.ExecuteScalar();
                Assert.Equal("Alicia", name);

                // Delete and verify
                cmd.CommandText = "DELETE FROM test_table WHERE name = 'Bob';";
                Assert.Equal(1, cmd.ExecuteNonQuery());

                cmd.CommandText = "SELECT COUNT(*) FROM test_table;";
                count = (long)cmd.ExecuteScalar();
                Assert.Equal(1, count);
            }
        }

        [Fact]
        public void ReadOnly_Connection_Prevents_Writes_But_Allows_Reads()
        {
            string filePath = Path.Combine(_tempDirectory, "readonly.db");
            string cs = SqliteDatabaseManager.BuildConnectionString(filePath, createIfNotExists: true, readOnly: false);

            // Create db and add one row
            using (var connection = SqliteDatabaseManager.CreateConnection(cs))
            {
                connection.Open();
                using var cmd = connection.CreateCommand();
                cmd.CommandText = "CREATE TABLE test_table (id INTEGER PRIMARY KEY, name TEXT);";
                cmd.ExecuteNonQuery();
                cmd.CommandText = "INSERT INTO test_table (name) VALUES ('Alice');";
                Assert.Equal(1, cmd.ExecuteNonQuery());
            }

            // Open read-only and verify read works
            string roCs = SqliteDatabaseManager.BuildConnectionString(filePath, createIfNotExists: false, readOnly: true);
            using (var roConnection = SqliteDatabaseManager.CreateConnection(roCs))
            {
                roConnection.Open();
                using var cmd = roConnection.CreateCommand();
                cmd.CommandText = "SELECT COUNT(*) FROM test_table;";
                var count = (long)cmd.ExecuteScalar();
                Assert.Equal(1, count);

                // Writes should fail
                cmd.CommandText = "INSERT INTO test_table (name) VALUES ('Charlie');";
                Assert.Throws<SqliteException>(() => cmd.ExecuteNonQuery());

                cmd.CommandText = "CREATE TABLE other_table (id INTEGER);";
                Assert.Throws<SqliteException>(() => cmd.ExecuteNonQuery());
            }
        }

        public void Dispose()
        {
            if (Directory.Exists(_tempDirectory))
            {
                try { Directory.Delete(_tempDirectory, recursive: true); } catch { }
            }
        }
    }
}
