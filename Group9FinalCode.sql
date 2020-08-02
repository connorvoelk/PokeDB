USE PROJ_A9

--BUSINESS RULES:
--Nikki
--A single species of Pokemon cannot have a base stat sum that exceeds 900 points
CREATE FUNCTION fn_NoBaseStatSumOver900()
RETURNS INT
AS
BEGIN
DECLARE @RET INT = 0

IF EXISTS ( SELECT *
			FROM tblPOKEMON_STAT PS
			JOIN tblPOKEMON P ON PS.PokemonID = P.PokemonID
			JOIN tblSPECIES S ON P.SpeciesID = S.SpeciesID
			GROUP BY S.SpeciesID
			HAVING SUM(PS.StatValue) > 900
			)

BEGIN
SET @RET = 1
END
RETURN @RET
END
GO

ALTER TABLE tblSPECIES
ADD CONSTRAINT CK_StatsDontExceed900
CHECK(dbo.fn_NoBaseStatSumOver900() = 0)
GO


--Nikki
--Water type Pokemon cannot have a base stat sum over 460 if they compete in the Competition 'RU' (Rarely Used)
CREATE FUNCTION fn_WaterTypeDefenseLimitsAttack()
RETURNS INT
AS
BEGIN
DECLARE @RET INT = 0

IF EXISTS ( SELECT *
			FROM tblSPECIES S
			JOIN tblSPECIES_TYPE_LIST STL ON S.SpeciesID = STL.SpeciesID
			JOIN tblTYPE T ON STL.TypeID = T.TypeID
			JOIN tblPOKEMON P ON S.SpeciesID = P.SpeciesID
			JOIN tblPOKEMON_STAT PS ON p.PokemonID = P.PokemonID
			JOIN tblSTAT ST ON PS.StatID = ST.StatID
			JOIN tblBATTLE_STAT BS ON ST. StatID = BS.StatID
			JOIN tblBATTLE B ON BS.BattleID = B.BattleID
			JOIN tblCOMP_CLASS CC ON B.CompClassID = CC.CompClassID

			WHERE T.TypeName = 'Water'
			AND CC.CompClassName = 'RU'
			AND S.BaseStatSum > 460
			)

BEGIN
	SET @RET = 1
END
RETURN @RET
END
GO

ALTER TABLE tblTEAM_POKEMON
ADD CONSTRAINT CK_LowSpecDefLowAttack
CHECK(dbo.fn_WaterTypeDefenseLimitsAttack() = 0)
GO

--Maria
-- Business rule that a species can have a maximum of 2 types
CREATE FUNCTION mmatlick_maxtypes()
RETURNS INT
AS
BEGIN
	DECLARE @RET INT = 0
	IF EXISTS (SELECT S.SpeciesID, S.SpeciesName, STL.NumTypes
				FROM tblSPECIES S
				JOIN tblSPECIES_TYPE_LIST STL ON S.SpeciesID = STL.SpeciesID
				JOIN tblTYPE T ON STL.TypeID = T.TypeID
				GROUP BY S.SpeciesID, S.SpeciesName, STL.NumTypes
				HAVING STL.NumTypes > 2)

		BEGIN
			SET @RET = 1
		END

	RETURN @RET
END
GO
ALTER TABLE tblTYPE
ADD CONSTRAINT MaxTypes
CHECK (dbo.mmatlick_maxtypes() = 0)
GO
--Maria
-- Each team must be made up of unique species
CREATE FUNCTION mmatlick_uniquespecies()
RETURNS INT
AS
BEGIN
	DECLARE @RET INT = 0
		IF EXISTS (SELECT *
					FROM tblSPECIES S
					JOIN tblPOKEMON P ON S.SpeciesID = P.SpeciesID
					JOIN tblTEAM_POKEMON TP ON P.PokemonID = TP.PokemonID
					HAVING COUNT(TP.PokemonID) > 1 )
	BEGIN
			SET @RET = 1
		END

	RETURN @RET
END
GO

ALTER TABLE tblTEAM_POKEMON
ADD CONSTRAINT UniquePokemonOnly
CHECK (dbo.mmatlick_uniquespecies() = 0)
GO
--Connor
--Business rule: Teams have a max of 6 pokemon on them
CREATE FUNCTION fnMaxSixPokeOnTeam()
RETURNS INT
AS
    BEGIN
        DECLARE @Ret INT = 0
            IF EXISTS (SELECT tT.TeamID, COUNT(tP.PokemonID)
                  FROM tblTEAM tT
                    JOIN tblTEAM_POKEMON tTP on tT.TeamID = tTP.TeamID
                    JOIN tblPOKEMON tP on tTP.PokemonID = tP.PokemonID
                  GROUP BY tT.TeamID
                  HAVING COUNT(tP.PokemonID) > 6)
            BEGIN
                SET @Ret = 1
            end
        RETURN @Ret
    end
GO
ALTER TABLE tblTEAM_POKEMON
ADD CONSTRAINT CKmaxSixPokeOnTeam
CHECK(dbo.fnMaxSixPokeOnTeam() = 0)
GO
--Connor
--Business rule: Pokemon have a max of 4 moves in a moveset
CREATE FUNCTION fnMovesetMax()
RETURNS INT
AS
    BEGIN
        DECLARE @Ret INT = 0
        IF EXISTS(SELECT tP.PokemonID, COUNT(tM.MoveID)
                  FROM tblPOKEMON tP
                    JOIN tblMOVESET tMS on tP.PokemonID = tMS.PokemonID
                    JOIN tblMOVE tM on tMS.MoveID = tM.MoveID
                  GROUP BY tP.PokemonID
                  HAVING COUNT(tM.MoveID) > 4)
            BEGIN
                SET @Ret = 1
            end
        RETURN @Ret
    end
GO
ALTER TABLE tblMOVESET
ADD CONSTRAINT CKmovesetMax
CHECK(dbo.fnMovesetMax() = 0)
GO

--Mackenzie
-- No team can be in two battles occurring at the same time
ALTER FUNCTION dbo.fn_NoTeamBattleSameTime()
RETURNS INT
AS
BEGIN
DECLARE @Ret INT = 0
IF EXISTS (
	SELECT *
	FROM tblBATTLE
	GROUP BY Team1ID, BattleDate, StartTime, EndTime
	HAVING COUNT(*) > 1
)
BEGIN
SET @RET = 1
END
IF EXISTS (
	SELECT *
	FROM tblBATTLE
	GROUP BY Team2ID, BattleDate, StartTime, EndTime
	HAVING COUNT(*) > 1
)
BEGIN
SET @RET = 1
END
RETURN @Ret
END
GO

ALTER TABLE tblBATTLE WITH NOCHECK
ADD CONSTRAINT NoTeamBattlesSameTime
CHECK(dbo.fn_NoTeamBattleSameTime()=0)
GO

--Mackenzie
--A Trainer can have no more than 5 teams - Mackenzie
CREATE FUNCTION dbo.fn_NoMore5TeamsPerTrainer()
RETURNS INT
AS
BEGIN
DECLARE @Ret INT = 0
IF EXISTS (
	SELECT T.TrainerID, COUNT(T.TeamID)
	FROM tblTRAINER TR JOIN tblTEAM T ON TR.TrainerID = T.TrainerID
	GROUP BY T.TrainerID
	HAVING COUNT(T.TeamID) > 5
)
BEGIN
SET @RET = 1
END
RETURN @Ret
END
GO

ALTER TABLE tblBATTLE WITH NOCHECK
ADD CONSTRAINT NoMore5TeamsPerTrain
CHECK(dbo.fn_NoMore5TeamsPerTrainer()=0)
GO

--COMPUTED COLUMNS
--Nikki
--Computed column for # of teams a trainer has
CREATE FUNCTION fn_TotalTeamsPerTrainer(@PK_ID INT)
RETURNS INT
AS
BEGIN

DECLARE @RET INT = (SELECT COUNT(T.TeamID)
					FROM tblTEAM T
					JOIN tblTRAINER TR ON T.TrainerID = TR.TrainerID
					WHERE TR.TrainerID = @PK_ID
					)
RETURN @RET
END

ALTER TABLE tblTRAINER
ADD TotalNumberOfTeams
AS (dbo.fn_TotalTeamsPerTrainer(TrainerID))
GO
--Nikki
--Computed column for # of Fairy type moves existing with a Base Power over 50 and Power Points under 15
CREATE FUNCTION fn_TotalFairyMovesBPOver50PPUnder15(@PK_ID INT)
RETURNS INT
AS
BEGIN
DECLARE @RET INT = (SELECT COUNT(M.MoveID)
					FROM tblMOVE M
					JOIN tblMOVE_TYPE MT ON M.MoveTypeID = MT.MoveTypeID

					WHERE M.MoveID = @PK_ID
					AND MT.MoveTypeName = 'Fairy'
					AND M.BasePower > 50
					AND M.MovePowerPoints < 15
					GROUP BY M.MoveID
					)
RETURN @RET
END
GO
ALTER TABLE tblMOVE
ADD TotalFairyMovesOver50BPAndUnder15PP
AS (dbo.fn_TotalFairyMovesBPOver50PPUnder15(MoveID))

GO



--Mackenzie
--Number of wins a trainer has (across all teams)
CREATE FUNCTION fn_CalcNumWinsTeam(@PK INT)
RETURNS INT
AS
BEGIN
DECLARE @RET INT =
(SELECT COUNT(BattleWinner)
FROM tblBATTLE
WHERE BattleWinner = @PK)
RETURN @RET
END
GO

ALTER TABLE tblTrainer
ADD NumTrainerWins AS (dbo.fn_CalcNumWinsTeam(TrainerID))
GO

--Mackenzie
--Number of pokemon who use a certain move
ALTER FUNCTION fn_NumMovesInSets(@PK INT)
RETURNS INT
AS
BEGIN
DECLARE @RET INT =
(SELECT COUNT(MS.PokemonID)
FROM tblMOVE M JOIN tblMOVESET MS ON M.MoveID = M.MoveID
WHERE MS.MoveID = @PK)
RETURN @RET
END
GO

ALTER TABLE tblMOVE
ADD NumMovesInSets AS (dbo.fn_NumMovesInSets(MoveID))
GO

--Connor
--Computed Column: Winner column in a battle (gives the TeamID of the winner of the battle)
CREATE FUNCTION fnGetBattleWinner(@BattlePK INT)
RETURNS INT
AS
    BEGIN
        DECLARE @Ret INT
        DECLARE @Team1Kockouts INT = (SELECT StatValue
                                      FROM tblBATTLE_STAT
                                        JOIN tblBATTLE t on tblBATTLE_STAT.BattleID = t.BattleID
                                        JOIN tblSTAT tS on tblBATTLE_STAT.StatID = tS.StatID
                                        WHERE StatName = 'Team1 Knockouts'
                                            AND t.BattleID = @BattlePK)
        DECLARE @Team2Kockouts INT = (SELECT StatValue
                                      FROM tblBATTLE_STAT
                                        JOIN tblBATTLE t on tblBATTLE_STAT.BattleID = t.BattleID
                                        JOIN tblSTAT tS on tblBATTLE_STAT.StatID = tS.StatID
                                        WHERE StatName = 'Team2 Knockouts'
                                            AND t.BattleID = @BattlePK)
        IF @Team1Kockouts > @Team2Kockouts
            BEGIN
                SET @Ret = (SELECT Team1ID
                            FROM tblBATTLE
                            WHERE BattleID = @BattlePK)
            end
        ELSE
            BEGIN
                SET @Ret = (SELECT Team2ID
                            FROM tblBATTLE
                            WHERE BattleID = @BattlePK)
            end
        RETURN @Ret
    end
GO

ALTER TABLE tblBATTLE
ADD BattleWinner
AS(dbo.fnGetBattleWinner(BattleID))
GO

--Connor
--Computed Column: Make a win count for the Team Table
CREATE FUNCTION fnGetNumWins(@TeamPK INT)
RETURNS INT
AS
    BEGIN
        DECLARE @Ret INT = (SELECT COUNT(t.BattleID)
                          FROM tblTEAM tT
                            JOIN tblBATTLE t on tT.TeamID = t.Team1ID --OR tT.TeamID = t.Team2ID
                          WHERE tT.TeamID = @TeamPK
                            AND t.BattleWinner = @TeamPK)
        SET @Ret = @Ret + (SELECT COUNT(t.BattleID)
                          FROM tblTEAM tT
                            JOIN tblBATTLE t on tT.TeamID = t.Team2ID
                          WHERE tT.TeamID = @TeamPK
                            AND t.BattleWinner = @TeamPK)
        RETURN @Ret
    end
GO

ALTER TABLE tblTEAM
ADD NumOfWins
AS(dbo.fnGetNumWins(TeamID))
GO

--Maria
-- Computed column for # of species types
CREATE FUNCTION mmatlick_num_types(@PK INT)
RETURNS INT
AS
BEGIN
	DECLARE @RET INT = (
		SELECT COUNT(T.TypeID)
		FROM tblTYPE T
			JOIN tblSPECIES_TYPE_LIST STL ON T.TypeID = STL.TypeID
			JOIN tblSPECIES S ON STL.SpeciesID = S.SpeciesID
		WHERE S.SpeciesID = @PK
)
RETURN @RET
END
GO

ALTER TABLE tblSPECIES_TYPE_LIST
ADD NumTypes
AS (dbo.mmatlick_num_types(SpeciesID))
GO

--Maria
-- Number of total species per type
CREATE FUNCTION mmatlick_num_types_species(@PK INT)
RETURNS INT
AS
BEGIN
	DECLARE @RET INT = (
		SELECT COUNT(T.TypeID)
		FROM tblSPECIES S
			JOIN tblSPECIES_TYPE_LIST STL ON S.SpeciesID = STL.SpeciesID
			JOIN tblTYPE T ON STL.TypeID = T.TypeID
		WHERE T.TypeID = @PK
)
RETURN @RET
END
GO

ALTER TABLE tblTYPE
ADD TotalTypes
AS (dbo.mmatlick_num_types_species(TypeID))
GO

--STORED PROCEDURES


--Connor
--Procedure to get the ItemID from an ItemName
CREATE PROCEDURE uspGetItemID
    @ItemName varchar(30),
    @ID INT OUTPUT
    AS
    SET @ID = (SELECT ItemID FROM tblITEM WHERE ItemName = @ItemName)

--Conor
--Populates a pokemon with their name, species and Item
CREATE PROCEDURE uspPopPokemon
    @SpeciesName varchar(100),
    @Item varchar(30),
    @PokemonNickName varchar(40)
    AS
       PRINT '70'
        DECLARE @SpeciesID INT = (SELECT SpeciesID FROM tblSPECIES WHERE SpeciesName = @SpeciesName)
       PRINT '80'
        -- ^ This could be a nested sproc when it is made, Its not ok if this is NULL
         IF @SpeciesID IS NULL
            BEGIN
                PRINT 'Species ID is not found, species may not exist';
                 THROW 54665, 'Species ID is not found, species may not exist', 1;
            end
        DECLARE @ItemID INT
        EXEC uspGetItemID
            @ItemName = @Item,
            @ID = @ItemID OUTPUT
        --ITs ok if this is null!

        BEGIN TRAN t1
        INSERT INTO tblPOKEMON(SpeciesID, ItemID, PokemonNickname)
        VALUES (@SpeciesID, @ItemID, @PokemonNickName)
        IF @@ERROR <> 0
    BEGIN
        PRINT 'TRAN t1 is terminating due to some error'
        ROLLBACK TRAN t1
    end
ELSE
        COMMIT TRAN t1

--Connor
--Gets the pokemonID with the relevant info!
CREATE PROCEDURE uspGetPokemonID
    @PokemonNickName varchar(40),
    @SpeciesName varchar(100),
    @TrainerName varchar(50),
    @ID INT OUTPUT
    AS
    SET @ID = (SELECT tP.PokemonID
                FROM tblPOKEMON tP
                    JOIN tblSPECIES tS on tP.SpeciesID = tS.SpeciesID
                    JOIN tblTEAM_POKEMON tTP on tP.PokemonID = tTP.PokemonID
                    JOIN tblTEAM tT on tTP.TeamID = tT.TeamID
                    JOIN tblTRAINER t on tT.TrainerID = t.TrainerID
                WHERE tP.PokemonNickname = @PokemonNickName
                    AND tS.SpeciesName = @SpeciesName
                    AND t.TrainerName = @TrainerName)

--Connor
--Gets the StatID from its name
CREATE PROCEDURE uspGetStatID
    @StatName varchar(30),
    @ID INT OUTPUT
    AS
    SET @ID = (SELECT StatName FROM tblSTAT WHERE StatName = @StatName)

--Connor
--Populate PokemonStat with the information to identify a pokemon, the stat and what the value is
CREATE PROCEDURE uspPopPokemonStat
    @NickName varchar(40),
    @Species varchar(100),
    @Trainer varchar(50),
    @Stat varchar(30),
    @Value INT
    AS
        DECLARE @StatID INT, @PokemonID INT
        EXEC uspGetPokemonID
            @PokemonNickName = @NickName,
            @SpeciesName = @Species,
            @TrainerName = @Trainer,
            @ID = @PokemonID OUTPUT
        IF @PokemonID IS NULL
            BEGIN
                PRINT 'Pokemon ID is not found, Pokemon may not exist';
                 THROW 54665, 'Pokemon ID is not found, Pokemon may not exist', 1;
            end
        EXEC uspGetStatID
            @StatName = @Stat,
            @ID = @StatID OUTPUT
        IF @StatID IS NULL
            BEGIN
                PRINT 'Stat ID is not found, stat may not exist';
                 THROW 54665, 'Stat ID is not found, stat may not exist', 1;
            end

BEGIN TRAN t1
INSERT INTO tblPOKEMON_STAT (PokemonID, StatID, StatValue)
    VALUES(@PokemonID, @StatID, @Value)
IF @@ERROR <> 0
    BEGIN
        PRINT 'TRAN t1 is terminating due to some error'
        ROLLBACK TRAN t1
    end
ELSE
    COMMIT TRAN t1


--Nikki
--Populate MoveType

CREATE PROCEDURE uspPopMoveType
@NewTypeName varchar(50)

AS
IF @NewTypeName IS NULL
		BEGIN
			PRINT '@NewTypeName  cannot be NULL, please give it a value.'
			RAISERROR ('@NewTypeName cannot be NULL; check spelling', 11,1)
			RETURN
		END

BEGIN TRANSACTION N1
INSERT INTO tblMOVE_TYPE(MoveTypeName)
VALUES (@NewTypeName)
IF @@ERROR <> 0
	BEGIN
		PRINT 'TRAN N1 is terminating due to an error. Good luck debugging!'
		ROLLBACK TRAN N1
	END
ELSE
COMMIT TRANSACTION N1

--Nikki
--Populate Ability
CREATE PROCEDURE uspPopAbility
@NewAbilName varchar(30),
@NewAbilDescr varchar(255)

AS
IF @NewAbilName IS NULL
		BEGIN
			PRINT '@NewAbilName  cannot be NULL, please give it a value.'
			RAISERROR ('@NewAbilName cannot be NULL; check spelling', 11,1)
			RETURN
		END

IF @NewAbilDescr IS NULL
		BEGIN
			PRINT '@NewAbilDescr  cannot be NULL, please give it a value.'
			RAISERROR ('@NewAbilDescr cannot be NULL; check spelling', 11,1)
			RETURN
		END

BEGIN TRANSACTION N2
INSERT INTO tblABILITY(AbilityName, AbilityDescr)
VALUES (@NewAbilName, @NewAbilDescr)
IF @@ERROR <> 0
	BEGIN
		PRINT 'TRAN N2 is terminating due to an error. Good luck debugging!'
		ROLLBACK TRAN N2
	END
ELSE
COMMIT TRANSACTION N2


--Mackenzie
--GetID Stored Procedures to leverage to populate Battle and BattleStat in a single Explicit Transaction
CREATE PROCEDURE dbo.uspGetTrainerID
@TrainName VARCHAR(30),
@TrainID INT OUTPUT
AS
SET @TrainID = (SELECT TrainerID FROM tblTRAINER WHERE TrainerName = @TrainName)
GO

CREATE PROCEDURE dbo.uspGetTeamID
@TeamyName VARCHAR(30),
@TrainyName VARCHAR(30),
@TeamyID INT OUTPUT
AS
DECLARE @TrainyID INT
EXEC dbo.uspGetTrainerID
@TrainName = @TrainyName,
@TrainID = @TrainyID OUTPUT
SET @TeamyID = (SELECT TeamID FROM tblTEAM WHERE TrainerID = @TrainyID AND TeamName = @TeamyName)
GO

CREATE PROCEDURE dbo.uspGetBattleTypeID
@BTypeName VARCHAR(30),
@BTypeID INT OUTPUT
AS
SET @BTypeID = (SELECT BattleTypeID FROM tblBATTLE_TYPE WHERE BattleTypeName = @BTypeName)
GO

CREATE PROCEDURE dbo.uspGetCompClassID
@CClassName VARCHAR(30),
@CClassID INT OUTPUT
AS
SET @CClassID = (SELECT CompClassID FROM tblCOMP_CLASS WHERE CompClassname = @CClassName)
GO

ALTER PROCEDURE dbo.uspPopBattleBattleSt
@Trn1Name VARCHAR(30),
@Tm1Name VARCHAR(30),
@Trn2Name VARCHAR(30),
@Tm2Name VARCHAR(30),
@CmpClName VARCHAR(30),
@BtlDate DATE,
@StrtTime TIME,
@EdTime TIME,
@BtlTypeName VARCHAR(30),
@Tm1Knockouts INT,
@Tm2Knockouts INT
AS
DECLARE @Tm1ID INT, @Tm2ID INT, @CmpClID INT, @BtlTypeID INT, @BtlID INT
EXEC dbo.uspGetTeamID
@TeamyName = @Tm1Name,
@TrainyName = @Trn1Name,
@TeamyID = @Tm1ID OUTPUT

IF @Tm1ID IS NULL
BEGIN
	PRINT 'NULL values found';
	THROW 54665, '@Tm1ID cannot be null', 1;
END

EXEC dbo.uspGetTeamID
@TeamyName = @Tm2Name,
@TrainyName = @Trn2Name,
@TeamyID = @Tm2ID OUTPUT

IF @Tm2ID IS NULL
BEGIN
	PRINT 'NULL values found';
	THROW 54665, '@Tm2ID cannot be null', 1;
END

IF @Tm1ID =  @Tm2ID
BEGIN
	PRINT 'A team cannot play themselves';
	THROW 54665, '@Tm1ID cannot equal @Tm2ID', 1;
END

EXEC dbo.uspGetCompClassID
@CClassName = @CmpClName,
@CClassID = @CmpCLID OUTPUT

IF @CmpClID IS NULL
BEGIN
	PRINT 'NULL values found';
	THROW 54665, '@CmpClID cannot be null', 1;
END

EXEC dbo.uspGetBattleTypeID
@BTypeName = @BtlTypeName,
@BTypeID = @BtlTypeID OUTPUT

IF @BtlTypeID IS NULL
BEGIN
	PRINT 'NULL values found';
	THROW 54665, '@BtlTypeID cannot be null', 1;
END

BEGIN TRAN T1
INSERT INTO tblBATTLE(BattleTypeID, Team1ID, Team2ID, CompClassID, BattleDate, StartTime, EndTime)
VALUES(@BtlTypeID, @Tm1ID, @Tm2ID, @CmpClID, @BtlDate, @StrtTime, @EdTime)

SET @BtlID = (SELECT scope_Identity())

INSERT INTO tblBATTLE_STAT(BattleID, StatID, StatValue)
VALUES(@BtlID, (SELECT StatID FROM tblSTAT WHERE StatName = 'Team1 Knockouts'), @Tm1Knockouts)

INSERT INTO tblBATTLE_STAT(BattleID, StatID, StatValue)
VALUES(@BtlID, (SELECT StatID FROM tblSTAT WHERE StatName = 'Team2 Knockouts'), @Tm2Knockouts)

IF @@ERROR <> NULL
BEGIN
	ROLLBACK TRAN T1
END
ELSE
	COMMIT TRAN T1
GO

--Maria
--Populate tblGENERATION
CREATE PROCEDURE mmatlick_populate_generation
@Gen_Name varchar(50),
@Gen_Descr varchar (200)

AS
IF @Gen_Name IS NULL
		BEGIN
			PRINT '@Gen_Name  cannot be NULL'
			RAISERROR ('@Gen_Name cannot be NULL; check spelling', 11,1)
			RETURN
		END

IF @Gen_Descr IS NULL
		BEGIN
			PRINT '@Gen_Descr  cannot be NULL'
			RAISERROR ('@Gen_Descr cannot be NULL; check spelling', 11,1)
			RETURN
		END

BEGIN TRANSACTION M1
INSERT INTO tblGENERATION (GenName, GenDescr)
VALUES (@Gen_Name, @Gen_Descr )
IF @@ERROR <> 0
	BEGIN
		PRINT 'TRAN M1 is terminating due to some error'
		ROLLBACK TRAN M1
	END
ELSE
COMMIT TRANSACTION M1
GO

--Maria
--Populate trainer
CREATE PROCEDURE mmatlick_populatetrainer
@TrainerFName varchar(50),
@TrainerLName varchar(50)

AS
IF @TrainerFName IS NULL
		BEGIN
			PRINT '@TrainerFName  cannot be NULL'
			RAISERROR ('@TrainerFNamecannot be NULL; check spelling', 11,1)
			RETURN
		END

IF @TrainerLName IS NULL
		BEGIN
			PRINT '@TrainerLName  cannot be NULL'
			RAISERROR ('@TrainerLNamecannot be NULL; check spelling', 11,1)
			RETURN
		END

BEGIN TRANSACTION M1
INSERT INTO tblTRAINER(TrainerName)
VALUES (CONCAT(@TrainerFName, '', @TrainerLName))
IF @@ERROR <> 0
	BEGIN
		PRINT 'TRAN M1 is terminating due to some error'
		ROLLBACK TRAN M1
	END
ELSE
COMMIT TRANSACTION M1

--VIEWS AND TABLE OBJECTS
--Nikki
/*Which Steel Type Pokemon from Generation 6 can learn more than 2 moves with a base power of 90 or more?
*/
CREATE VIEW Gen6SteelTypesWithStrongMoves AS
SELECT S.SpeciesID, S.SpeciesName
FROM tblSPECIES S
JOIN tblSPECIES_TYPE_LIST STL ON S.SpeciesID = STL.SpeciesID
JOIN tblTYPE T ON STL.TypeID = T.TypeID
JOIN tblGENERATION G ON S.GenID = G.GenID
JOIN tblPOKEMON P ON S.SpeciesID = P.SpeciesID
JOIN tblMOVESET MS ON P.PokemonID = MS.PokemonID
JOIN tblMOVE M ON MS.MoveID = M.MoveID

WHERE G.GenName = 'Generation VI'
AND T.TypeName = 'Steel'
AND M.BasePower >= 90

GROUP BY S.SpeciesID, S.SpeciesName
HAVING COUNT(M.MoveID) > 2
GO

--Nikki
/*Listed in the order of strongest to weakest, who are the strongest Pokemon in Generation 4 who are of the Flying type with at least 280 as their base stat total?
*/
CREATE VIEW StrongestGen4FlyingTypes AS
SELECT DISTINCT S.SpeciesID, S.SpeciesName, S.BaseStatSum
FROM tblSPECIES S
JOIN tblSPECIES_TYPE_LIST STL ON S.SpeciesID = STL.SpeciesID
JOIN tblTYPE T ON STL.TypeID = T.TypeID
JOIN tblGENERATION G ON S.GenID = G.GenID
JOIN tblPOKEMON P ON S.SpeciesID = P.SpeciesID
JOIN tblPOKEMON_STAT PS ON P.PokemonID = PS.PokemonID

WHERE G.GenName = 'Generation IV'
AND T.TypeName = 'Flying'
AND S.BaseStatSum > 280

ORDER BY S.BaseStatSum DESC
GO

--Maria
-- Rank trainers who have at least 17 wins using all generation 2 pokemon
WITH CTE_TrainerGenII_17Wins (Trainer_ID, Trainer_Name, Wins, TrainerRank)
AS
(SELECT T.TrainerID, T.TrainerName , TM.NumOfWins AS GenIIWins, RANK() OVER (ORDER BY TM.NumOfWins DESC)
FROM tblTRAINER T
	JOIN tblTEAM TM ON T.TrainerID = TM.TrainerID
	JOIN tblTEAM_POKEMON TP ON TM.TeamID = TP.TeamID
	JOIN tblPOKEMON P ON TP.PokemonID = P.PokemonID
	JOIN tblSPECIES S ON P.SpeciesID = S.SpeciesID
	JOIN tblGENERATION G ON S.GenID = G.GenID
WHERE G.GenName = 'Generation II' AND
TM.NumOfWins > 17
GROUP BY T.TrainerID, T.TrainerName, TM.NumOfWins)

SELECT Trainer_ID, Trainer_Name, Wins, TrainerRank
FROM CTE_TrainerGenII_17Wins

--Maria
--Rank trainers by most wins using only grass type pokemon
WITH CTE_TrainerWinsGrass(Trainer_ID, Trainer_Name, Wins, TrainerRank)
AS
(SELECT T.TrainerID, T.TrainerName, TM.NumOfWins AS GrassWins, RANK() OVER (ORDER BY TM.NumOfWins DESC)
FROM tblTRAINER T
	JOIN tblTEAM TM ON T.TrainerID = TM.TrainerID
	JOIN tblTEAM_POKEMON TP ON TM.TeamID = TP.TeamID
	JOIN tblPOKEMON P ON TP.PokemonID = P.PokemonID
	JOIN tblSPECIES S ON P.SpeciesID = S.SpeciesID
	JOIN tblSPECIES_TYPE_LIST ST ON S.SpeciesID = ST.SpeciesID
	JOIN tblTYPE TY ON ST.TypeID = TY.TypeID
WHERE TY.TypeName = 'Grass'
GROUP BY T.TrainerID, T.TrainerName, TM.NumOfWins)

SELECT Trainer_ID, Trainer_Name, Wins, TrainerRank
FROM CTE_TrainerWinsGrass

--Mackenzie
-- MOST POPULAR ABILITY AMONG POKEMON OF THE MOST RECENT GENERATION
WITH CTE_MostPopularAbilityNewestGen (AbilityID, AbilityName, TimesUsed, Ranking)
AS
(
	SELECT A.AbilityID, A.AbilityName, COUNT(A.AbilityID) AS TimesUsed,
	RANK() OVER (ORDER BY COUNT(A.AbilityID) DESC)
	FROM tblABILITY A JOIN tblSPECIES_ABILITY SA ON A.AbilityID = SA.AbilityID
		JOIN tblSPECIES S ON SA.SpeciesID = S.SpeciesID
		JOIN tblGENERATION G ON G.GenID = S.GenID
	WHERE G.GenID = (SELECT TOP 1 G.GenID FROM tblGENERATION G JOIN tblSPECIES S ON G.GenID = S.GenID ORDER BY G.GenID DESC)
	GROUP BY A.AbilityID, A.AbilityName
)
SELECT AbilityID, AbilityName, TimesUsed, Ranking
FROM CTE_MostPopularAbilityNewestGen
WHERE Ranking = 1

--Mackenzie
--Which stat has the highest stat value for all pokemon, of the most popular pokemon type?
WITH CTE_HighestStatMostPopType (StatID, StatName, TotalStatVal, Ranking)
AS (
	SELECT STA.StatID, STA.StatName, SUM(PS.StatValue) AS TotalStats,
	RANK() OVER (ORDER BY SUM(PS.StatValue) DESC) AS Ranking
	FROM tblTYPE T JOIN tblSPECIES_TYPE_LIST ST ON T.TypeID = ST.TypeID
		JOIN tblSPECIES S ON S.SpeciesID = ST.SpeciesID
		JOIN tblPOKEMON P ON P.SpeciesID = S.SpeciesID
		JOIN tblPOKEMON_STAT PS ON PS.PokemonID = P.PokemonID
		JOIN tblSTAT STA ON STA.StatID = PS.StatID
		JOIN (SELECT TOP 1 (TotalTypes), TypeID FROM tblTYPE ORDER BY TotalTypes DESC) AS SUBQ
		ON SUBQ.TypeID = T.TypeID
	GROUP BY STA.StatID, STA.StatName
)
SELECT StatID, StatName, TotalStatVal, Ranking
FROM CTE_HighestStatMostPopType
WHERE Ranking = 1

--Connor
--View: Which pokemon with more than 3 abilities and have all 6 PokemonStat valued above 90
CREATE VIEW vwManyAbilitiesGoodStats
AS
SELECT tP.PokemonID, tP.PokemonNickname, COUNT(tPS.PokemonStatID) AS AllStats, sq.AbilityCount
FROM tblPOKEMON tP
    JOIN tblPOKEMON_STAT tPS on tP.PokemonID = tPS.PokemonID
    JOIN tblSTAT tS on tPS.StatID = tS.StatID
    JOIN (SELECT tP.PokemonID, COUNT(tA.AbilityID) AS AbilityCount
        FROM tblPOKEMON tP
            JOIN tblSPECIES tS on tP.SpeciesID = tS.SpeciesID
            JOIN tblSPECIES_ABILITY tSA on tS.SpeciesID = tSA.SpeciesID
            JOIN tblABILITY tA on tSA.AbilityID = tA.AbilityID
        GROUP BY tP.PokemonID
        HAVING COUNT(tA.AbilityID) > 3) AS sq ON tP.PokemonID = sq.PokemonID
WHERE tPS.StatValue > 90
GROUP BY tP.PokemonID, tP.PokemonNickname, sq.AbilityCount
HAVING COUNT(tPS.PokemonStatID) = 6
--Connor
--View: Out of the top 20 teams ranked by their Pokemons' combined StatValues, have participated in over 10 "Double" Battles
CREATE VIEW StrongTeamsDoubles
AS
SELECT tT.TeamID, tT.TeamName, COUNT(*) AS DoubleBattleCount, sq.StatPower
FROM tblTEAM tT
    JOIN tblBATTLE t on (tT.TeamID = t.Team1ID OR tT.TeamID = t.Team2ID)
    JOIN tblBATTLE_TYPE tBT on t.BattleTypeID = tBT.BattleTypeID
    JOIN (
        SELECT TOP 20 tT.TeamID, SUM(tPS.StatValue) AS StatPower
        FROM tblTEAM tT
            JOIN tblTEAM_POKEMON tTP on tT.TeamID = tTP.TeamID
            JOIN tblPOKEMON tP on tTP.PokemonID = tP.PokemonID
            JOIN tblPOKEMON_STAT tPS on tP.PokemonID = tPS.PokemonID
        GROUP BY tT.TeamID, tT.TeamName
        ORDER BY SUM(tPS.StatValue) DESC
    ) AS sq ON tT.TeamID = sq.TeamID
WHERE tBT.BattleTypeName = 'Double'
GROUP BY tT.TeamID, tT.TeamName, sq.StatPower
HAVING COUNT(*) > 10

SELECT * FROM tblBATTLE
JOIN tblBATTLE_TYPE tBT on tblBATTLE.BattleTypeID = tBT.BattleTypeID


--CREATE TABLES
CREATE TABLE tblSTAT(
   StatID INT IDENTITY (1,1) PRIMARY KEY,
   StatName varchar(30) not null,
   StatDesc varchar(300) null
)

CREATE TABLE tblITEM(
   ItemID INT IDENTITY (1,1) PRIMARY KEY,
   ItemName varchar(max) not null,
   ItemDesc varchar(max) null
)

CREATE TABLE tblABILITY (
AbilityID INT IDENTITY(1,1) PRIMARY KEY,
AbilityName varchar(30) not null,
AbilityDescr varchar(255) not null
)

CREATE TABLE tblMOVE_TYPE (
MoveTypeID INT IDENTITY(1,1) PRIMARY KEY,
MoveTypeName varchar(15) not null
)

CREATE TABLE tblMOVE (
MoveID INT IDENTITY(1,1) PRIMARY KEY,
MoveTypeID INT FOREIGN KEY REFERENCES tblMOVE_TYPE(MoveTypeID) NOT NULL,
BasePower INT not null,
MoveName varchar(50) not null,
MovePowerPoints INT not null
)


CREATE TABLE tblTYPE (
TypeID INT IDENTITY (1,1) primary key not null,
TypeName varchar(50) not null)

CREATE TABLE tblGENERATION (
GenID INT IDENTITY (1,1) primary key not null,
GenName varchar(50) not null,
GenDescr varchar (200) not null)


CREATE TABLE tblTRAINER (
TrainerID INT IDENTITY (1,1) primary key not null,
TrainerName varchar(50) not null)


CREATE TABLE tblSPECIES (
SpeciesID INT IDENTITY (1,1) primary key not null,
SpeciesName varchar(100) not null,
SpeciesNumber varchar(3) not null,
SpeciesDescr varchar(100) null,
BaseStatSum varchar(3) not null,
GenID INT FOREIGN KEY REFERENCES tblGENERATION(GenID) not null)


CREATE TABLE tblSPECIES_TYPE_LIST (
SpeciesTypeListID INT IDENTITY (1,1) primary key not null,
SpeciesID INT FOREIGN KEY REFERENCES tblSPECIES(SpeciesID) not null,
TypeID INT FOREIGN KEY REFERENCES tblTYPE(TypeID) not null)

CREATE TABLE tblPOKEMON(
   PokemonID INT IDENTITY (1,1) PRIMARY KEY,
   SpeciesID INT FOREIGN KEY REFERENCES tblSPECIES(SpeciesID) not null,
   ItemID INT FOREIGN KEY REFERENCES tblITEM(ItemID) null,
   PokemonNickname varchar(40) null,
)

CREATE TABLE tblSPECIES_ABILITY (
SpeciesAbilityID INT IDENTITY(1,1) PRIMARY KEY,
SpeciesID INT FOREIGN KEY REFERENCES tblSPECIES(SpeciesID) NOT NULL,
AbilityID INT FOREIGN KEY REFERENCES tblABILITY(AbilityID) NOT NULL
)


CREATE TABLE tblPOKEMON_STAT(
   PokemonStatID INT IDENTITY (1,1) PRIMARY KEY,
   PokemonID INT FOREIGN KEY REFERENCES tblPOKEMON(PokemonID) not null,
   StatID INT FOREIGN KEY REFERENCES tblSTAT(StatID) not null,
   StatValue INT not null
)

CREATE TABLE tblMOVESET (
MovesetID INT IDENTITY(1,1) PRIMARY KEY,
PokemonID INT FOREIGN KEY REFERENCES tblPOKEMON(PokemonID) NOT NULL,
MoveID INT FOREIGN KEY REFERENCES tblMOVE(MoveID) NOT NULL
)



CREATE TABLE tblBATTLE_TYPE(
	BattleTypeID INT IDENTITY (1, 1) PRIMARY KEY NOT NULL,
	BattleTypeName VARCHAR(50) NOT NULL,
	BattleTypeDescr VARCHAR(100) NULL
)

CREATE TABLE tblCOMP_CLASS (
	CompClassID INT IDENTITY (1, 1) PRIMARY KEY NOT NULL,
	CompClassName VARCHAR(50) NOT NULL,
	CompClassDescr VARCHAR(100) NULL
)

CREATE TABLE tblTEAM (
	TeamID INT IDENTITY (1, 1) PRIMARY KEY,
	TrainerID INT FOREIGN KEY REFERENCES tblTRAINER(TrainerID) NOT NULL,
	TeamName VARCHAR(50) NOT NULL
)

CREATE TABLE tblTEAM_POKEMON (
	TeamPokemonID INT IDENTITY (1, 1) PRIMARY KEY NOT NULL,
	TeamID INT FOREIGN KEY REFERENCES tblTEAM(TeamID) NOT NULL,
	PokemonID INT FOREIGN KEY REFERENCES tblPOKEMON(PokemonID) NOT NULL,
	BeginDate DATE NOT NULL,
	EndDate DATE NULL
)

CREATE TABLE tblBATTLE(
	BattleID INT IDENTITY (1, 1) PRIMARY KEY NOT NULL,
	BattleTypeID INT FOREIGN KEY REFERENCES tblBATTLE_TYPE(BattleTypeID) NOT NULL,
	Team1ID INT FOREIGN KEY REFERENCES tblTEAM(TeamID) NOT NULL,
	Team2ID INT FOREIGN KEY REFERENCES tblTEAM(TeamID) NOT NULL,
	CompClassID INT FOREIGN KEY REFERENCES tblCOMP_CLASS(CompClassID) NOT NULL,
	BattleDate DATE NOT NULL,
	StartTime TIME NOT NULL,
	EndTime TIME NOT NULL,
)

CREATE TABLE tblBATTLE_STAT(
   BattleStatID INT IDENTITY (1,1) PRIMARY KEY,
   BattleID INT FOREIGN KEY REFERENCES tblBATTLE(BattleID) not null,
   StatID INT FOREIGN KEY REFERENCES tblSTAT(StatID) not null,
   StatValue INT not null
)
