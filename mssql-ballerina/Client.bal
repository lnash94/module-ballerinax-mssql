// Copyright (c) 2021 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/crypto;
import ballerina/jballerina.java;
import ballerina/sql;

# Represents a MsSQL database client.
public client class Client {
    *sql:Client;
    private boolean clientActive = true;

    # Initialize Mssql Client.
    #
    # + host - Hostname of the mssql server to be connected
    # + instance - Instance name of the server to be connected as mssql can have installations of multiple versions 
    #              under a single server.
    # + user - If the mssql server is secured, the username to be used to connect to the mssql server
    # + password - The password of provided username of the database
    # + database - The name fo the database to be connected
    # + port - Port number of the mssql server to be connected
    # + options - The Database specific JDBC client properties
    # + connectionPool - The `sql:ConnectionPool` object to be used within the jdbc client.
    #                   If there is no connectionPool is provided, the global connection pool will be used and it will
    #                   be shared by other clients which has same properties.
    public isolated function init(string host = "localhost", string instance ="", string? user = (), string? password = (), string? database = (),
        int port = 1433, Options? options = (), sql:ConnectionPool? connectionPool = ()) returns sql:Error? {
        ClientConfiguration clientConfig = {
            host: host,
            instance: instance,
            port: port,
            user: user,
            password: password,
            database: database,
            options: options,
            connectionPool: connectionPool
        };
        return createClient(self, clientConfig, sql:getGlobalConnectionPool());
    }

    # Queries the database with the query provided by the user, and returns the result as stream.
    #
    # + sqlQuery - The query which needs to be executed as `string` or `ParameterizedQuery` when the SQL query has
    #              params to be passed in
    # + rowType - The `typedesc` of the record that should be returned as a result. If this is not provided the default
    #             column names of the query result set be used for the record attributes.
    # + return - Stream of records in the type of `rowType`
    remote isolated function query(@untainted string|sql:ParameterizedQuery sqlQuery, typedesc<record {}>? rowType = ())
    returns @tainted stream <record {}, sql:Error> {
        if (self.clientActive) {
            return nativeQuery(self, sqlQuery, rowType);
        } else {
            return sql:generateApplicationErrorStream("MsSQL Client is already closed,"
                + "hence further operations are not allowed");
        }
    }

    # Executes the DDL or DML sql queries provided by the user, and returns summary of the execution.
    #
    # + sqlQuery - The DDL or DML query such as INSERT, DELETE, UPDATE, etc as `string` or `ParameterizedQuery`
    #              when the query has params to be passed in
    # + return - Summary of the sql update query as `ExecutionResult` or returns `Error`
    #           if any error occurred when executing the query
    remote isolated function execute(@untainted string|sql:ParameterizedQuery sqlQuery) returns sql:ExecutionResult|sql:Error {
        if (self.clientActive) {
            return nativeExecute(self, sqlQuery);
        } else {
            return error sql:ApplicationError("MsSQL Client is already closed, hence further operations are not allowed");
        }
    }

    # Executes a batch of parameterized DDL or DML sql query provided by the user,
    # and returns the summary of the execution.
    #
    # + sqlQueries - The DDL or DML query such as INSERT, DELETE, UPDATE, etc as `ParameterizedQuery` with an array
    #                of values passed in
    # + return - Summary of the executed SQL queries as `ExecutionResult[]` which includes details such as
    #            `affectedRowCount` and `lastInsertId`. If one of the commands in the batch fails, this function
    #            will return `BatchExecuteError`, however the JDBC driver may or may not continue to process the
    #            remaining commands in the batch after a failure. The summary of the executed queries in case of error
    #            can be accessed as `(<sql:BatchExecuteError> result).detail()?.executionResults`.
    remote isolated function batchExecute(@untainted sql:ParameterizedQuery[] sqlQueries) returns sql:ExecutionResult[]|sql:Error {
        if (sqlQueries.length() == 0) {
            return error sql:ApplicationError(" Parameter 'sqlQueries' cannot be empty array");
        }
        if (self.clientActive) {
            return nativeBatchExecute(self, sqlQueries);
        } else {
            return error sql:ApplicationError("MsSQL Client is already closed, hence further operations are not allowed");
        }
    }

    # Executes a SQL stored procedure and returns the result as stream and execution summary.
    #
    # + sqlQuery - The query to execute the SQL stored procedure
    # + rowTypes - The array of `typedesc` of the records that should be returned as a result. If this is not provided
    #               the default column names of the query result set be used for the record attributes.
    # + return - Summary of the execution is returned in `ProcedureCallResult` or `sql:Error`
    remote isolated function call(@untainted string|sql:ParameterizedCallQuery sqlQuery, typedesc<record {}>[] rowTypes = [])
    returns sql:ProcedureCallResult|sql:Error {
        if (self.clientActive) {
            return nativeCall(self, sqlQuery, rowTypes);
        } else {
            return error sql:ApplicationError("MsSQL Client is already closed, hence further operations are not allowed");
        }
    }

    # Close the SQL client.
    #
    # + return - Possible error during closing the client
    public isolated function close() returns sql:Error? {
        self.clientActive = false;
        return close(self);
    }

}

# Client Configuration record for connection initialization
#
# + host - Hostname of the mssql server to be connected
# + instance - Instance of mssql server to connect to on serverName
# + port - Port number of the mssql server to be connected
# + database - System Identifier or the Service Name of the database
# + user - Name of a user of the database
# + password - Password for the user
# + options - Mssql database specific JDBC options
# + connectionPool - The `sql:ConnectionPool` object to be used within 
#         the jdbc client. If there is no connectionPool provided, 
#         the global connection pool will be used
type ClientConfiguration record {|
    string host;
    string? instance;
    int port;
    string? user;
    string? password;
    string? database;
    Options? options;
    sql:ConnectionPool?  connectionPool;
|};

# MsSQL database options.
#
# + ssl - SSL Configuration to be used
# + useXADatasource - Boolean value to enable XADatasource
# + socketTimeout - The number of milliseconds to wait before a timeout is occurred 
#                   on a socket read or accept. The default value is 0, which means 
#                   infinite timeout.
# + queryTimeout - The number of seconds to wait before a timeout has occurred on a 
#                  query. The default value is -1, which means infinite timeout. 
#                  Setting this to 0 also implies to wait indefinitely.
# + loginTimeout - The number of seconds the driver should wait before timing out a 
#                 failed connection. A zero value indicates that the timeout is the 
#                 default system timeout, which is specified as 15 seconds by default. 
#                 A non-zero value is the number of seconds the driver should wait 
#                 before timing out a failed connection.

public type Options record {|
    SecureSocket ssl = {};
    boolean useXADatasource = false;
    decimal socketTimeout?;
    decimal queryTimeout?;
    decimal loginTimeout?;
|};

# SSL Configuration to be used when connecting to Mssql server.
#
# + clientCertKeystore - Keystore configuration of the client certificates
# + trustCertKeystore - Keystore configuration of the trust certificates
# + encrypt - encryption for all the data sent between the client and the server if the server has a certificate installed
# + trustServerCertificate - If "true", the SQL Server SSL certificate is automatically trusted when the communication layer is encrypted using TLS.
# + trustStore - The path (including filename) to the certificate trustStore file. The trustStore file contains the list of certificates that the client trusts.
# + trustStorePassword - The password used to check the integrity of the trustStore data.

//TODO 
public type SecureSocket record {|
    boolean encrypt?;
    boolean trustServerCertificate?;
    string trustStore?;
    string trustStorePassword?;
    crypto:KeyStore clientCertKeystore?;
    crypto:KeyStore trustCertKeystore?;
|};

isolated function createClient(Client mssqlclient, ClientConfiguration clientConfig, sql:ConnectionPool globalConnPool) returns sql:Error? = @java:Method{
    'class: "org.ballerinalang.mssql.nativeimpl.ClientProcessorUtils"
} external;

isolated function nativeQuery(Client sqlClient, string|sql:ParameterizedQuery sqlQuery, typedesc<record {}>? rowType)
returns stream <record {}, sql:Error> = @java:Method {
    'class: "org.ballerinalang.mssql.nativeimpl.QueryProcessorUtils"
} external;

isolated function nativeExecute(Client sqlClient, string|sql:ParameterizedQuery sqlQuery)
returns sql:ExecutionResult|sql:Error = @java:Method {
    'class: "org.ballerinalang.mssql.nativeimpl.ExecuteProcessorUtils"
} external;

isolated function nativeBatchExecute(Client sqlClient, sql:ParameterizedQuery[] sqlQueries)
returns sql:ExecutionResult[]|sql:Error = @java:Method {
    'class: "org.ballerinalang.mssql.nativeimpl.ExecuteProcessorUtils"
} external;

isolated function nativeCall(Client sqlClient, string|sql:ParameterizedCallQuery sqlQuery, typedesc<record {}>[] rowTypes)
returns sql:ProcedureCallResult|sql:Error = @java:Method {
    'class: "org.ballerinalang.mssql.nativeimpl.CallProcessorUtils"
} external;

isolated function close(Client mssqlClient) returns sql:Error? = @java:Method {
    'class: "org.ballerinalang.mssql.nativeimpl.ClientProcessorUtils"
} external;
