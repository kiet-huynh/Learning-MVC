CREATE TABLE GameConsoles (
    GameConsoleId UNIQUEIDENTIFIER NOT NULL CONSTRAINT
		DF_GameConsoles_Id DEFAULT NEWSEQUENTIALID(),
    GameConsoleCode VARCHAR(30),
    GameConsoleName VARCHAR(255),
    CreatedDate DATETIME2,
    CreatedBy VARCHAR(255),
    UpdatedDate DATETIME2,
    UpdatedBy VARCHAR(255),
    CONSTRAINT PK_GameConsole
        PRIMARY KEY (GameConsoleId)
);
