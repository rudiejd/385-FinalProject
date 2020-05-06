
/***********************************************************************************************
	
	Authors:			JD Rudie, Joe Faflik, John Murray,
	Class:				CSE 385 D
	Instructor:			Mr. Michael Stahr
	Purpose:			Creating a database that tracks prices at different stores
	Initial Creation:	4/19/2020
	Licensed Under:		MIT License

************************************************************************************************/

USE master
GO

IF DB_ID('StoreDB') IS NOT NULL DROP DATABASE StoreDB
GO

CREATE DATABASE StoreDB
GO

USE [StoreDB]
GO


/*==================================================================================================

											TABLES

====================================================================================================*/

CREATE TABLE ItemType(
	itemTypeId		INT				NOT NULL	PRIMARY KEY		IDENTITY,
	[name]			VARCHAR(50)		NOT NULL,
	[description]	VARCHAR(200)	NOT NULL
)

CREATE TABLE Brand(
	brandId			INT				NOT NULL	PRIMARY KEY		IDENTITY,
	[name]			VARCHAR(50)		NOT NULL,
	[description]	VARCHAR(200)	NOT NULL,
	isDeleted		BIT				NOT NULL
)

CREATE TABLE Item(
	itemId			INT				NOT NULL	PRIMARY KEY		IDENTITY,
	brandId			INT				NOT NULL	FOREIGN KEY REFERENCES Brand(brandId),
	itemTypeId		INT				NOT NULL	FOREIGN KEY REFERENCES ItemType(itemTypeId),
	[name]			VARCHAR(50)		NOT NULL,
	[description]	VARCHAR(200)	NOT NULL,
	isDeleted		BIT				NOT NULL
)

CREATE TABLE [User](
	userId			INT				NOT NULL	PRIMARY KEY		IDENTITY,
	firstName		VARCHAR(50)		NOT NULL,
	lastName		VARCHAR(50)		NOT NULL,
	userName		VARCHAR(50)		NOT NULL,
	email			VARCHAR(50)		NOT NULL,
	[password]		VARBINARY(64)	NOT NULL,
	goodLoginCount	INT				DEFAULT 0	NOT NULL,	
	badLoginCount	INT				DEFAULT 0	NOT NULL,	
	isDeleted		BIT				DEFAULT 0	NOT NULL,	
)

CREATE TABLE UserRegistration (
	userId			INT				NOT NULL	PRIMARY KEY		IDENTITY,
	isActive		BIT				DEFAULT 0	NOT NULL,
	token			CHAR(10)
)

CREATE TABLE StoreItem(
	itemId			INT				NOT NULL,
	storeId			INT				NOT NULL,
	userId			INT				NOT NULL	FOREIGN KEY REFERENCES [User](userId),
	price			MONEY			NOT NULL,
	[date]			DATE			NOT NULL,
	comments		VARCHAR(200)	NOT NULL,
	PRIMARY KEY (itemId, storeId)
)

CREATE TABLE Store(
	storeId			INT				NOT NULL	PRIMARY KEY		IDENTITY,
	[address]		VARCHAR(200)	NOT NULL,
	storeName		VARCHAR(100)	NOT NULL,
	contactName		VARCHAR(50)		NOT NULL,
	phoneNumber		VARCHAR(20)		NOT NULL,
	website			VARCHAR(200)	NOT NULL
)

/*
==================================================================================================

											VIEWS

==================================================================================================
*/

GO

CREATE VIEW vwItem AS
	SELECT *
	FROM Item
	WHERE isDeleted = 0;

GO

CREATE VIEW vwBrand AS
	SELECT *
	FROM Brand
	WHERE isDeleted = 0;

GO

CREATE VIEW vwUser AS
	SELECT *
	FROM [User]
	WHERE isDeleted = 0;

GO

/*
==================================================================================================

											TRIGGERS

==================================================================================================
*/



/*
==================================================================================================

										STORED FUNCTIONS

==================================================================================================
*/
 

CREATE FUNCTION fnEncrypt (@str	AS	nvarchar(4000)) RETURNS varbinary(64) AS BEGIN	
	RETURN HASHBYTES('SHA2_512', @str)	
END

GO




/*
==================================================================================================

										STORED PROCEDURES

==================================================================================================
*/


/*************************************************************************************************
	
	Name:		spAddUpdateDelete_User
	Purpose:	Adds updates or deletes a user. Creates registration token to confirm reg.
	Written:	5/6/2020
	Author:		JD Rudie
	Returns:	-1 if operation failed, >= 0 if operation succeeded

**************************************************************************************************/
CREATE PROCEDURE spAddUpdateDelete_User 
	@userId		INT,	
	@firstName	VARCHAR	(50),
	@lastName	VARCHAR	(50),
	@userName	VARCHAR	(50),
	@email		VARCHAR	(50),
	@password	NVARCHAR(4000), 
	@delete		BIT = 0
AS BEGIN
BEGIN TRAN
	BEGIN TRY 
		IF(@userId = 0) BEGIN																				-- ADD
			IF(EXISTS (SELECT NULL FROM [User] WHERE userName = @userName OR email = @email)) BEGIN
				SELECT -1
			END
			ELSE BEGIN
				DECLARE @insertId INT
				INSERT INTO [User] (firstName, lastName, userName, email, [password]) 
				VALUES (@firstName, @lastName, @userName, @email, dbo.fnEncrypt(@password))

				INSERT INTO UserRegistration (token) 
				VALUES (SUBSTRING(REPLACE(newid(), '-', ''), 1, 10))

				SELECT @@IDENTITY AS userId
			END
		END ELSE IF(@delete = 1) BEGIN																		-- DELETE
			IF (EXISTS(SELECT NULL FROM StoreItem WHERE userId = @userId)) BEGiN							-- soft 
				UPDATE Users SET isDeleted = 1 WHERE userId = @userId;
				SELECT 0 AS userId
			END ELSE BEGIN																					-- hard
				DELETE FROM Users WHERE userId = @userId;
				SELECT 0 AS userId
			END
		END ELSE BEGIN																						-- UPDATE
			IF EXISTS (SELECT NULL FROM [User] WHERE userId = @userId) AND NOT EXISTS ( SELECT NULL FROM users WHERE userId != @userId AND (userName = @userName OR email = @email)) BEGIN
				UPDATE [User] SET	firstName = @firstName, lastName = @lastName, userName = @userName,
									email = @email 
				WHERE userId = @userId;

				SELECT @userId AS userId
			END ELSE BEGIN
				SELECT -1 AS userId
			END
		END
	END TRY BEGIN CATCH
		IF (@@TRANCOUNT > 0) ROLLBACK TRAN
		DECLARE @errParams VARCHAR(MAX) = CONCAT ('userId = ', @userId, ' firstName = ', @firstName,
												'lastName = ', @lastName, ' userName = ', @userName,
												'email = ', @email, 'password = ', @password, ' delete = ', @delete);
		EXEC sp_Save_Error @params = @errParams;  
	END CATCH
		IF (@@TRANCOUNT > 0) COMMIT TRAN
END

GO



/*************************************************************************************************
	
	Name:		spSave_Error
	Purpose:	Saves an error into the errors table
	Written:	5/6/2020
	Author:		JD Rudie
	Returns:	Error information 

**************************************************************************************************/
CREATE PROCEDURE spSave_Error
	@params varchar(MAX) = ''
AS
BEGIN
     SET NOCOUNT ON;
     BEGIN TRY
    	INSERT INTO errors (ERROR_NUMBER,   ERROR_SEVERITY,   ERROR_STATE,   ERROR_PROCEDURE,   ERROR_LINE,   ERROR_MESSAGE, userName, params)
		SELECT				ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_PROCEDURE(), ERROR_LINE(), ERROR_MESSAGE(), SUSER_NAME(), @params;
     END TRY BEGIN CATCH END CATCH
END







/*
==================================================================================================

									DATA INSERTION AND TESTS

==================================================================================================
*/