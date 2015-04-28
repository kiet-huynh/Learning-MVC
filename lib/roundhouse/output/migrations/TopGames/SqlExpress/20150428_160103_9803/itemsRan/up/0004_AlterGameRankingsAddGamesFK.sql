ALTER TABLE GameRankings
    ADD	CONSTRAINT FK_GameRankings_GameId
		FOREIGN KEY (GameId) REFERENCES Games(GameId)
;
