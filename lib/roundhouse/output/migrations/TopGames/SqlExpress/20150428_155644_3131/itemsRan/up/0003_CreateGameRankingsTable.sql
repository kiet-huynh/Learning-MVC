CREATE TABLE GameRankings (
    GameRankingId UNIQUEIDENTIFIER NOT NULL CONSTRAINT
		DF_GameRanking_Id DEFAULT NEWSEQUENTIALID(),
	GameConsoleId UNIQUEIDENTIFIER NOT NULL,
	GameId UNIQUEIDENTIFIER NOT NULL,
    GameRanking INT,
    GameRankingName VARCHAR(255),
    CreatedDate DATETIME2,
    CreatedBy VARCHAR(255),
    UpdatedDate DATETIME2,
    UpdatedBy VARCHAR(255),
    CONSTRAINT PK_GameRanking
        PRIMARY KEY (GameRankingId),
	CONSTRAINT FK_GameRankings_GameConsoleId
		FOREIGN KEY (GameConsoleId) REFERENCES GameConsoles(GameConsoleId)
);
