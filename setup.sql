
/***********************************************************************************************
	
	Authors:			JD Rudie, Joe Faflik, John Murray
	Class:				CSE 385 D
	Instructor:			Mr. Michael Stahr
	Purpose:			Creating a database that tracks prices at different stores
	Initial Creation:	4/19/2020
	Licensed Under:		MIT License

************************************************************************************************/
USE MASTER;

GO

DROP DATABASE IF EXISTS StoreDB;

GO

CREATE DATABASE StoreDB
GO

USE [StoreDB]
GO


/*==================================================================================================

											TABLES

====================================================================================================*/

CREATE TABLE ItemType(
	itemTypeId				INT				NOT NULL	PRIMARY KEY		IDENTITY,
	itemTypeName			VARCHAR(50)		NOT NULL,
	itemTypeDescription		VARCHAR(200)	NOT NULL,
	isDeleted				BIT				DEFAULT 0	NOT NULL
)

CREATE TABLE Brand(
	brandId					INT				NOT NULL	PRIMARY KEY		IDENTITY,
	brandName				VARCHAR(50)		NOT NULL,
	brandDescription		VARCHAR(200)	NOT NULL,
	isDeleted				BIT				DEFAULT 0	NOT NULL
)

CREATE TABLE Item(
	itemId					INT				NOT NULL	PRIMARY KEY		IDENTITY,
	brandId					INT				NOT NULL	FOREIGN KEY REFERENCES Brand(brandId),
	itemTypeId				INT				NOT NULL	FOREIGN KEY REFERENCES ItemType(itemTypeId),
	itemName				VARCHAR(50)		NOT NULL,
	itemDescription			VARCHAR(200)	NOT NULL,
	avgPrice				MONEY			DEFAULT 0	NOT NULL,
	isDeleted				BIT				DEFAULT 0	NOT NULL	
)

CREATE TABLE [User](
	userId					INT				NOT NULL	PRIMARY KEY		IDENTITY,
	firstName				VARCHAR(50)		NOT NULL,
	lastName				VARCHAR(50)		NOT NULL,
	userName				VARCHAR(50)		NOT NULL,
	email					VARCHAR(50)		NOT NULL,
	[password]				VARBINARY(64)	NOT NULL,
	goodLoginCount			INT				DEFAULT 0	NOT NULL,	
	badLoginCount			INT				DEFAULT 0	NOT NULL,	
	isDeleted				BIT				DEFAULT 0	NOT NULL,	
)

CREATE TABLE UserRegistration (
	userId					INT				NOT NULL	FOREIGN KEY REFERENCES [User](userId),
	isActive				BIT				NOT NULL	DEFAULT 0,
	regDate					DATETIME		NOT NULL	DEFAULT	GETDATE(),
	token					CHAR(10)		NOT NULL	DEFAULT SUBSTRING(REPLACE(newid(), '-', ''), 1, 10)
)

CREATE TABLE PasswordReset (
	userId					INT				NOT NULL	FOREIGN KEY REFERENCES [User](userId),
	resetDate				DATETIME		NOT NULL	DEFAULT	GETDATE(),
	token					CHAR(30)		NOT NULL	DEFAULT SUBSTRING(REPLACE(newid(), '-', ''), 1, 30)
)

CREATE TABLE Store(
	storeId					INT				NOT NULL	PRIMARY KEY		IDENTITY,
	[address]				VARCHAR(200)	NOT NULL,
	storeName				VARCHAR(100)	NOT NULL,
	contactName				VARCHAR(50)		NOT NULL,
	phoneNumber				VARCHAR(20)		NOT NULL,
	website					VARCHAR(200)	NOT NULL,
	isDeleted				BIT				DEFAULT 0	NOT NULL
)

CREATE TABLE StoreItem(
	storeItemId				INT				NOT NULL	PRIMARY KEY		IDENTITY,
	itemId					INT				NOT NULL	FOREIGN KEY REFERENCES Item(itemId),
	storeId					INT				NOT NULL	FOREIGN KEY REFERENCES Store(storeId),
	userId					INT				NOT NULL	FOREIGN KEY REFERENCES [User](userId),
	price					MONEY			NOT NULL,
	[date]					DATETIME		NOT NULL,
	comments				VARCHAR(200)	NOT NULL,
)

CREATE TABLE Error(
	ERROR_NUMBER			INT				NOT NULL,   
	ERROR_SEVERITY			INT				NOT NULL,   
	ERROR_STATE				INT				NOT NULL,   
	ERROR_PROCEDURE			VARCHAR(MAX)	NOT NULL,   
	ERROR_LINE				INT				NOT NULL,   
	ERROR_MESSAGE			VARCHAR(MAX)	NOT NULL,
	ERROR_DATETIME			DATETIME		NOT NULL,
	userName				VARCHAR(100)	NOT NULL,
	params					VARCHAR(MAX)	NOT NULL,
)
	
GO

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

CREATE VIEW vwStore AS
	SELECT *
	FROM Store
	WHERE isDeleted = 0;

GO

CREATE VIEW vwItemType AS
	SELECT *
	FROM ItemType
	WHERE isDeleted = 0;

GO


CREATE VIEW vwUser AS
	SELECT *
	FROM [User] u
	WHERE isDeleted = 0 AND (SELECT isActive FROM UserRegistration ur WHERE ur.userId = u.userId) = 1;

GO

/*
==================================================================================================

											TRIGGERS

==================================================================================================
*/

/*************************************************************************************************
	
	Name:		trUpdate_AvgItemPrice
	Purpose:	Updates average item price after a new StoreItem is inserted, updated, or deleted
	Written:	5/7/2020
	Author:		JD Rudie

**************************************************************************************************/
CREATE TRIGGER trUpdate_AvgItemPrice
ON StoreItem AFTER INSERT, UPDATE, DELETE AS
BEGIN
	DECLARE @price MONEY, @itemId INT
	IF EXISTS (SELECT TOP(1) NULL FROM deleted) BEGIN
		 IF (UPDATE(price) OR UPDATE(itemId)) BEGIN																												-- if it's an update
			DECLARE @oldPrice MONEY, @oldItemId INT;
			
			DECLARE updCurIns CURSOR FOR (SELECT price, itemId FROM inserted)
			OPEN updCurIns
			DECLARE updCurDel CURSOR FOR (SELECT price, itemId FROM deleted)
			OPEN updCurDel
			
			FETCH NEXT FROM updCurIns
			INTO @price, @itemId
			
			FETCH NEXT FROM updCurDel
			INTO @oldPrice, @oldItemId
			
			WHILE @@FETCH_STATUS = 0
			BEGIN
				IF @itemId = @oldItemId BEGIN
					UPDATE Item SET avgPrice = ( ((SELECT avgPrice FROM Item WHERE itemId = @itemid)*(SELECT COUNT(*) FROM StoreItem WHERE itemId = @itemId)) - @oldPrice + @price ) / ( (SELECT COUNT(*) FROM StoreItem WHERE itemId = @itemId) ) 
					WHERE itemId = @itemId
				END ELSE BEGIN
					UPDATE Item SET avgPrice = ( (SELECT avgPrice FROM Item WHERE itemId = @itemid) + @price ) / ( (SELECT COUNT(*) FROM StoreItem WHERE itemId = @itemId) ) 
					WHERE itemId = @itemId
					FETCH NEXT FROM insCur
					INTO @price, @itemId
				END
			
				FETCH NEXT FROM updCurIns
				INTO @price, @itemId
			
				FETCH NEXT FROM updCurDel
				INTO @oldPrice, @oldItemId
			END
			
			CLOSE updCurIns
			DEALLOCATE updCurIns
			
			CLOSE updCurDel
			DEALLOCATE updCurDel
			
			END ELSE BEGIN																																			-- if it's a delete
				DECLARE delCur CURSOR FOR (SELECT price, itemId FROM deleted)
			
				OPEN delCur
				FETCH NEXT FROM delCur
				INTO @price, @itemId
			
				WHILE @@FETCH_STATUS = 0
				BEGIN
					IF (EXISTS (SELECT * FROM StoreItem WHERE itemId = @itemid)) BEGIN
						UPDATE Item SET avgPrice = ( ( (SELECT avgPrice FROM Item WHERE itemId = @itemid) *  ( (SELECT COUNT(*) FROM StoreItem WHERE itemId = @itemId) + 1 )) - @price ) / ( (SELECT COUNT(*) FROM StoreItem WHERE itemId = @itemId) )
						WHERE itemid = @itemId
					END ELSE BEGIN
						UPDATE Item Set avgPrice = 0
						WHERE itemId = @itemId
					END
					FETCH NEXT FROM delCur
					INTO @price, @itemId
				END
			
				CLOSE delCur
				DEALLOCATE delCur;
			END
	END ELSE BEGIN																																				-- otherwise it's just an add
		DECLARE insCur CURSOR FOR (SELECT price, itemId FROM inserted)
		OPEN insCur
		FETCH NEXT FROM insCur
		INTO @price, @itemId
		WHILE @@FETCH_STATUS = 0
		BEGIN

			UPDATE Item SET avgPrice = ( (SELECT avgPrice FROM Item WHERE itemId = @itemid) + @price ) / ( (SELECT COUNT(*) FROM StoreItem WHERE itemId = @itemId) ) 
			WHERE itemId = @itemId
			FETCH NEXT FROM insCur
			INTO @price, @itemId
		END

		CLOSE insCur
		DEALLOCATE insCur;
	END

END


GO



/*
==================================================================================================

										STORED FUNCTIONS

==================================================================================================
*/
 
/*************************************************************************************************
	
	Name:		fnEncrypt
	Purpose:	Encrypts a string with SHA2_512 encryption
	Written:	5/6/2020
	Author:		JD Rudie
	Returns:	HASHBYTES (SHA2_512) of string 

**************************************************************************************************/
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
    	INSERT INTO Error (ERROR_NUMBER,   ERROR_SEVERITY,   ERROR_STATE,   ERROR_PROCEDURE,   ERROR_LINE,   ERROR_MESSAGE, ERROR_DATETIME, userName, params)
		SELECT				ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_PROCEDURE(), ERROR_LINE(), ERROR_MESSAGE(), GETDATE(), SUSER_NAME(), @params;
     END TRY BEGIN CATCH END CATCH
END

GO


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
				INSERT INTO [User] (firstName, lastName, userName, email, [password]) 
				VALUES (@firstName, @lastName, @userName, @email, dbo.fnEncrypt(@password))

				DECLARE @lastInsert INT;
				SET @lastInsert = @@IDENTITY

				INSERT INTO UserRegistration (userId) 
				VALUES (@lastInsert)

				SELECT @lastInsert AS userId
			END
		END ELSE IF(@delete = 1) BEGIN																		-- DELETE
			IF (EXISTS(SELECT NULL FROM StoreItem WHERE userId = @userId)) BEGiN							-- soft 
				UPDATE [User] SET isDeleted = 1 WHERE userId = @userId;
				SELECT 0 AS userId
			END ELSE BEGIN
				DELETE FROM UserRegistration WHERE userId = @userId											-- hard
				DELETE FROM [User] WHERE userId = @userId;
				SELECT 0 AS userId
				
			END
		END ELSE BEGIN																						-- UPDATE
			IF EXISTS (SELECT NULL FROM [User] WHERE userId = @userId) AND NOT EXISTS ( SELECT NULL FROM [User] WHERE userId != @userId AND (userName = @userName OR email = @email)) BEGIN
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
		EXEC spSave_Error @params = @errParams;  
	END CATCH
		IF (@@TRANCOUNT > 0) COMMIT TRAN
END

GO


/*************************************************************************************************
	
	Name:		spAddUpdateDelete_Store
	Purpose:	Adds updates or deletes a store
	Written:	5/6/2020
	Author:		JD Rudie
	Returns:	-1 if operation failed, >= 0 if operation succeeded

**************************************************************************************************/
CREATE PROCEDURE spAddUpdateDelete_Store
	@storeId		INT,	
	@address		VARCHAR	(200),
	@storeName		VARCHAR	(100),
	@contactName	VARCHAR	(50),
	@phoneNumber	VARCHAR	(20),
	@website		VARCHAR(200), 
	@delete			BIT = 0
AS BEGIN
BEGIN TRAN
	BEGIN TRY 
		IF(@storeId = 0) BEGIN																				-- ADD
			INSERT INTO Store ([address], storeName, contactName, phoneNumber, website) 
			VALUES (@address, @storeName, @contactName, @phoneNumber, @website)

			SELECT @@IDENTITY AS storeId
		END ELSE IF(@delete = 1) BEGIN																		-- DELETE
			IF (EXISTS(SELECT NULL FROM StoreItem WHERE storeId = @storeId)) BEGiN							-- soft 
				UPDATE Store SET isDeleted = 1 WHERE storeId = @storeId;
				SELECT 0 AS storeId;
			END ELSE BEGIN																					-- hard
				DELETE FROM Store WHERE storeId = @storeId;
				SELECT 0 AS storeId
			END
		END ELSE BEGIN																						-- UPDATE
			IF EXISTS (SELECT NULL FROM Store WHERE storeId = @storeId) BEGIN
				UPDATE Store SET	[address] = @address, storeName = @storeName, contactName = @contactName, phoneNumber = @phoneNumber, website = @website
				WHERE storeId = @storeId
				SELECT @storeId AS storeId
			END ELSE BEGIN
				SELECT -1 AS userId
			END
		END
	END TRY BEGIN CATCH
		IF (@@TRANCOUNT > 0) ROLLBACK TRAN
		DECLARE @errParams VARCHAR(MAX) = CONCAT	('address = ', @address, 'storeName = ', @storeName, 'contactName = ', 
													@contactName, 'phoneNumber = ', @phoneNumber, 'website = ', @website);
		EXEC spSave_Error @params = @errParams;  
	END CATCH
		IF (@@TRANCOUNT > 0) COMMIT TRAN
END

GO

/*************************************************************************************************
	
	Name:		spAddUpdateDelete_Brand
	Purpose:	Adds updates or deletes a brand
	Written:	5/6/2020
	Author:		JD Rudie
	Returns:	-1 if operation failed, >= 0 if operation succeeded

**************************************************************************************************/
CREATE PROCEDURE spAddUpdateDelete_Brand
	@brandId				INT,	
	@brandName				VARCHAR(50),
	@brandDescription		VARCHAR(200),
	@delete					BIT = 0
AS BEGIN
BEGIN TRAN
	BEGIN TRY 
		IF(@brandId = 0) BEGIN																			-- ADD
			INSERT INTO Brand (brandName, brandDescription)
			VALUES (@brandName, @brandDescription)
			SELECT @@IDENTITY AS brandId;
		END ELSE IF(@delete = 1) BEGIN																		-- DELETE
			IF (EXISTS(SELECT NULL FROM Item WHERE brandId = @brandId)) BEGiN								-- soft 
				UPDATE Brand SET isDeleted = 1 WHERE brandId = @brandId;
				SELECT 0 AS brandId;
			END ELSE BEGIN																					-- hard
				DELETE FROM Brand
				WHERE brandId = @brandId
				SELECT 0 AS brandId;
			END
		END ELSE BEGIN																						-- UPDATE
			UPDATE Brand SET brandName = @brandName, brandDescription = @brandDescription
			WHERE brandId = @brandId		
		END
	END TRY BEGIN CATCH
		IF (@@TRANCOUNT > 0) ROLLBACK TRAN
		DECLARE @errParams VARCHAR(MAX) = CONCAT ('brandId = ', @brandId, ' brandName = ', @brandName, ' brandDescription = ', @brandDescription)
		EXEC spSave_Error @params = @errParams;  
	END CATCH
		IF (@@TRANCOUNT > 0) COMMIT TRAN
END

GO

/*************************************************************************************************
	
	Name:		spAddUpdateDelete_ItemType
	Purpose:	Adds updates or deletes an ItemType
	Written:	5/6/2020
	Author:		JD Rudie
	Returns:	-1 if operation failed, >= 0 if operation succeeded

**************************************************************************************************/
CREATE PROCEDURE spAddUpdateDelete_ItemType 
	@itemTypeId				INT,	
	@itemTypeName			VARCHAR(50),
	@itemTypeDescription	VARCHAR(200),
	@delete					BIT = 0
AS BEGIN
BEGIN TRAN
	BEGIN TRY 
		IF(@itemTypeId = 0) BEGIN																			-- ADD
			INSERT INTO ItemType (itemTypeName, itemTypeDescription)
			VALUES (@itemTypeName, @itemTypeDescription)
				
			SELECT @@IDENTITY AS itemTypeId; 
		END ELSE IF(@delete = 1) BEGIN																		-- DELETE
			IF (EXISTS(SELECT NULL FROM Item WHERE itemTypeId = @itemTypeId)) BEGiN							-- soft 
				UPDATE ItemType SET isDeleted = 1 WHERE itemTypeId = @itemTypeId;
				SELECT 0 AS itemTypeId;
			END ELSE BEGIN																					-- hard
				DELETE FROM ItemType
				WHERE itemTypeId = @itemTypeId
				SELECT 0 AS itemTypeId;
			END
		END ELSE BEGIN																						-- UPDATE
			UPDATE ItemType SET itemTypeName = @itemTypeName, itemTypeDescription = @itemTypeDescription
			WHERE itemTypeId = @itemTypeId			
		END
	END TRY BEGIN CATCH
		IF (@@TRANCOUNT > 0) ROLLBACK TRAN
		DECLARE @errParams VARCHAR(MAX) = CONCAT ('itemTypeId = ', @itemTypeId, ' itemTypeName = ', @itemTypeName, ' itemTypeDescription = ', @itemTypeDescription)
		EXEC spSave_Error @params = @errParams;  
	END CATCH
		IF (@@TRANCOUNT > 0) COMMIT TRAN
END

GO

/*************************************************************************************************
	
	Name:		spAddUpdateDelete_Item
	Purpose:	Adds updates or deletes an item
	Written:	5/6/2020
	Author:		JD Rudie
	Returns:	-1 if operation failed, >= 0 if operation succeeded

**************************************************************************************************/
CREATE PROCEDURE spAddUpdateDelete_Item 
	@itemId				INT,	
	@brandId			INT,
	@itemTypeId			INT,
	@itemName			VARCHAR(50),
	@itemDescription	VARCHAR(200),
	@delete				BIT = 0
AS BEGIN
BEGIN TRAN
	BEGIN TRY 
		IF(@itemId = 0) BEGIN																				-- ADD
			IF(NOT EXISTS (SELECT NULL FROM Brand WHERE brandId = @brandId) OR NOT EXISTS(SELECT NULL FROM ItemType WHERE itemTypeId = @itemTypeId)) BEGIN
				SELECT -1
			END
			ELSE BEGIN
				INSERT INTO Item (brandId, itemTypeId, itemName, itemDescription)
				VALUES (@brandId, @itemTypeId, @itemName, @itemDescription)
				
				SELECT @@IDENTITY AS itemId; 
			END
		END ELSE IF(@delete = 1) BEGIN																		-- DELETE
			IF (EXISTS(SELECT NULL FROM StoreItem WHERE itemId = @itemId)) BEGiN							-- soft 
				UPDATE Item SET isDeleted = 1 WHERE itemId = @itemId;
				SELECT 0 AS itemId;
			END ELSE BEGIN																					-- hard
				DELETE FROM Item
				WHERE itemId = @itemId
				SELECT 0 AS itemId;
			END
		END ELSE BEGIN																						-- UPDATE
			IF(NOT EXISTS (SELECT NULL FROM Brand WHERE brandId = @brandId) OR NOT EXISTS(SELECT NULL FROM ItemType WHERE itemTypeId = @itemTypeId)) BEGIN
				SELECT -1
			END ELSE BEGIN
				UPDATE Item SET brandId = @brandId, itemTypeId = @itemTypeId, itemName = @itemName, itemDescription = @itemDescription
				WHERE itemId = @itemId			
			END 
		END
	END TRY BEGIN CATCH
		IF (@@TRANCOUNT > 0) ROLLBACK TRAN
		DECLARE @errParams VARCHAR(MAX) = CONCAT	('itemId = ', @itemId, ' brandId = ', @brandId, ' itemTypeId = ', @itemTypeId, ' itemName = ', @itemName, ' itemDescription = ', @itemDescription);
		EXEC spSave_Error @params = @errParams;  
	END CATCH
		IF (@@TRANCOUNT > 0) COMMIT TRAN
END

GO

/*************************************************************************************************
	
	Name:		spAddUpdateDelete_StoreItem
	Purpose:	Adds updates or deletes a StoreItem
	Written:	5/6/2020
	Author:		JD Rudie
	Returns:	-1 if operation failed, >= 0 if operation succeeded

**************************************************************************************************/

CREATE PROCEDURE spAddUpdateDelete_StoreItem 
	@storeItemId	INT,
	@itemId			INT,	
	@storeId		INT,
	@userId			INT,
	@price			MONEY,
	@date			DATETIME,
	@comments		VARCHAR(200),
	@delete			BIT = 0
AS BEGIN
BEGIN TRAN
	BEGIN TRY 
		IF(@storeItemId = 0) BEGIN																			-- ADD
			IF(NOT EXISTS (SELECT NULL FROM Item WHERE itemId = @itemId) OR NOT EXISTS(SELECT NULL FROM Store WHERE storeId = @storeId) 
				OR NOT EXISTS (SELECT NULL FROM [User] WHERE userId = @userId)) BEGIN
				SELECT -1
			END
			ELSE BEGIN
				INSERT INTO StoreItem (itemId, storeId, userId, price, [date], comments)
				VALUES (@itemId, @storeId, @userId, @price, @date, @comments)

				SELECT @@IDENTITY AS storeItemid
			END
		END ELSE IF(@delete = 1) BEGIN																		-- DELETE															
				DELETE FROM StoreItem
				WHERE storeItemId = @storeItemId
				SELECT 0 AS storeItemId
		END ELSE BEGIN																						-- UPDATE
			IF(NOT EXISTS (SELECT NULL FROM Item WHERE itemId = @itemId) OR NOT EXISTS(SELECT NULL FROM Store WHERE storeId = @storeId) 
				OR NOT EXISTS (SELECT NULL FROM [User] WHERE userId = @userId)) BEGIN
				SELECT -1
			END ELSE BEGIN
				UPDATE StoreItem SET itemId = @itemId, storeId = @storeId, userId = @userId, price = @price, [date] = @date, comments = @comments
				WHERE storeItemId = @storeItemId
			END 
		END
	END TRY BEGIN CATCH
		IF (@@TRANCOUNT > 0) ROLLBACK TRAN
		DECLARE @errParams VARCHAR(MAX) = CONCAT	('storeItemId = ', @storeItemId, ' itemId = ', @itemId, ' storeId = ', @storeId, ' userId = ', @userId, 
													'price = ', @price, ' date = ', @date, ' comments = ', @comments);
		EXEC spSave_Error @params = @errParams;  
	END CATCH
		IF (@@TRANCOUNT > 0) COMMIT TRAN
END

GO
/*************************************************************************************************
	
	Name:		spLogin
	Purpose:	Logs a user in, checking password against database
	Written:	5/8/2020
	Author:		JD Rudie
	Returns:	0 if successful, -1 if not successful

**************************************************************************************************/
CREATE PROCEDURE spLogin
	@userId			INT,
	@password		NVARCHAR(4000)
AS BEGIN
	IF EXISTS (SELECT NULL FROM vwUser WHERE [password] = dbo.fnEncrypt(@password) AND userID = @userId) BEGIN			-- Check if the token is valid and it's been less than one hour
		UPDATE [User] SET goodLoginCount = goodLoginCount + 1
		WHERE userId = @userId
		SELECT 0
	END ELSE BEGIN
		UPDATE [User] SET badLoginCount = badLoginCount + 1
		WHERE userId = @userId
		SELECT -1
	END
END


GO


/*************************************************************************************************
	
	Name:		spConfirm_Email
	Purpose:	Confirms a user's email address and sets them to active
	Written:	5/6/2020
	Author:		JD Rudie
	Returns:	0 if successful, -1 if not successful

**************************************************************************************************/
CREATE PROCEDURE spConfirm_Email
	@userId			INT,
	@token			CHAR(10)
AS BEGIN
	IF EXISTS (SELECT NULL FROM UserRegistration WHERE token = @token AND DATEDIFF(HOUR, regDate, GETDATE()) <= 1) BEGIN			-- Check if the token is valid and it's been less than one hour
		UPDATE UserRegistration SET isActive = 1 WHERE userId = @userId
		SELECT 0
	END ELSE BEGIN
		SELECT -1
	END
END


GO

/*************************************************************************************************
	
	Name:		spConfirm_ResetPassword
	Purpose:	Confirms a user's password reset and changes user password
	Written:	5/6/2020
	Author:		JD Rudie
	Returns:	0 if successful, -1 if not successful

**************************************************************************************************/
CREATE PROCEDURE spConfirm_PasswordReset
	@userId			INT,
	@token			CHAR(30),
	@newPassword	NVARCHAR(4000)
AS BEGIN
	IF EXISTS (SELECT NULL FROM PasswordReset WHERE token = @token AND DATEDIFF(HOUR, resetDate, GETDATE()) <= 1) BEGIN		-- Check if the token is valid and it's been less than one hour
		UPDATE [User] SET [password] = dbo.fnEncrypt(@newPassword) WHERE userId = @userId
		SELECT 0
	END ELSE BEGIN
		SELECT -1
	END
END

GO

/*************************************************************************************************
	
	Name:		spReset_Password
	Purpose:	Set up a password reset by inserting a random token into the PasswordReset table
	Written:	5/6/2020
	Author:		JD Rudie
	Returns:	0 if successful, -1 if not successful

**************************************************************************************************/
CREATE PROCEDURE spReset_Password
	@userId			INT
AS BEGIN
	IF EXISTS (SELECT NULL FROM [User] WHERE userId = @userId) BEGIN
		DELETE FROM PasswordReset WHERE userId = @userId												-- Delete last password reset entry if they choose to reset again
		INSERT INTO PasswordReset (userId) VALUES (@userId)
		SELECT 0
	END ELSE BEGIN
		SELECT -1
	END
END

GO

/*************************************************************************************************
	
	Name:		spReset_RegistrationToken
	Purpose:	Resets the confirmation token sent to the user's email
	Written:	5/6/2020
	Author:		JD Rudie
	Returns:	0 if successful, -1 if not successful

**************************************************************************************************/
CREATE PROCEDURE spReset_RegistrationToken
	@userId			INT
AS BEGIN
	IF EXISTS (SELECT NULL FROM UserRegistration WHERE userId = @userId) BEGIN
		DELETE FROM UserRegistration WHERE userId = @userId												
		INSERT INTO UserRegistration (userId) VALUES (@userId)
		SELECT 0
	END ELSE BEGIN
		SELECT -1
	END
END

GO



/*************************************************************************************************
	
	Name:		spGet_StoreItemsByStore 
	Purpose:	Gets all store items for a particular store
	Written:	5/7/2020
	Author:		John Murray
	Returns:	JSON list of store items from a store

**************************************************************************************************/

CREATE PROCEDURE spGet_StoreItemsByStore
	@storeId	INT
AS
BEGIN
	SELECT (
		SELECT DISTINCT	i.itemId, i.itemName, i.itemDescription, i.avgPrice,
				[brand] = (SELECT brandId, brandName, brandDescription FROM vwBrand WHERE brandId = i.brandId FOR JSON PATH),
				[itemType] = (SELECT itemTypeId, itemTypeName, itemTypeDescription FROM vwItemType WHERE itemTypeId = i.itemTypeId FOR JSON PATH)
		FROM vwStore s
		JOIN StoreItem si	ON si.storeId = s.storeId
		JOIN vwItem i		ON i.itemId = si.itemId
		WHERE s.storeId = @storeId
		FOR JSON PATH
	) FOR XML PATH('')
END

GO



/*************************************************************************************************
	
	Name:		spGet_StoresByItem
	Purpose:	Gets all stores that hold a given itemId
	Written:	5/7/2020
	Author:		John Murray
	Returns:	JSON list of stores with given item

**************************************************************************************************/

CREATE PROCEDURE spGet_StoresByItem
	@itemId INT
AS
BEGIN
	SELECT (
		SELECT	s.storeId, s.address, s.storeName, s.contactName, s.phoneNumber, s.website
		FROM vwStore s
		JOIN StoreItem si ON si.itemId = @itemId AND si.storeId = s.storeId
		FOR JSON PATH
	) FOR XML PATH('')
END

GO


/*************************************************************************************************
	
	Name:		spGet_StoreItemsByPrice
	Purpose:	Gets all store items that are less than or equal to a price
	Written:	5/7/2020
	Author:		John Murray
	Returns:	JSON list of store items that are less than or equal to a price

**************************************************************************************************/

CREATE PROCEDURE spGet_StoreItemsByPrice
	@price MONEY
AS
BEGIN
	SELECT (
		SELECT	si.itemId, si.storeId, si.userId, si.price, si.date, si.comments, 
				[itemName] = (SELECT itemName FROM vwItem WHERE itemId = si.itemId),
				[storeName] = (SELECT storeName FROM vwStore WHERE storeId = si.storeId)
		FROM StoreItem si
		WHERE si.price <= @price
		FOR JSON PATH
	) FOR XML PATH('')
END

GO

/*************************************************************************************************
	
	Name:		spGet_Stores 
	Purpose:	Lists all stores in database
	Written:	5/7/2020
	Author:		John Murray
	Returns:	JSON list of stores

**************************************************************************************************/

CREATE PROCEDURE spGet_ListStores
	
AS
BEGIN
	SELECT (
		SELECT	*
		FROM vwStore
		FOR JSON PATH
	) FOR XML PATH('')
END

GO

/*************************************************************************************************
	
	Name:		spGet_Brands
	Purpose:	Lists all brands in database
	Written:	5/7/2020
	Author:		John Murray
	Returns:	JSON list of brands

**************************************************************************************************/

CREATE PROCEDURE spGet_Brands
	
AS
BEGIN
	SELECT (
		SELECT	brandId, brandName, brandDescription
		FROM vwBrand
		FOR JSON PATH
	) FOR XML PATH('')
END

GO

/*************************************************************************************************
	
	Name:		spGet_Users
	Purpose:	Lists all users in database
	Written:	5/7/2020
	Author:		John Murray
	Returns:	JSON list of users

**************************************************************************************************/

CREATE PROCEDURE spGet_Users
	
AS
BEGIN
	SELECT (
		SELECT	userId, firstName, lastName, userName, email, goodLoginCount, badLoginCount
		FROM vwUser
		WHERE isDeleted = 0
		FOR JSON PATH
	) FOR XML PATH('')
END

GO


/*************************************************************************************************
	
	Name:		spGet_ListItems
	Purpose:	Lists all items in database
	Written:	5/7/2020
	Author:		John Murray
	Returns:	JSON list of items

**************************************************************************************************/

CREATE PROCEDURE spGet_ListItems
	
AS
BEGIN
	SELECT(
		SELECT	i.itemId, i.itemName, i.itemDescription, i.avgPrice,
				[brand] = (SELECT brandId, brandName, brandDescription FROM vwBrand WHERE brandId = i.brandId FOR JSON PATH),
				[itemType] = (SELECT itemTypeId, itemTypeName, itemTypeDescription FROM vwItemType WHERE itemTypeId = i.itemTypeId FOR JSON PATH)
		FROM vwItem i
		FOR JSON PATH
	) FOR XML PATH('')
END

GO

/*************************************************************************************************
	
	Name:		spGet_StoreItemsByUser
	Purpose:	Lists all storeItems given a userId
	Written:	5/7/2020
	Author:		John Murray
	Returns:	JSON list of storeItems from user

**************************************************************************************************/

CREATE PROCEDURE spGet_StoreItemsByUser
	@userId	INT
AS
BEGIN
	SELECT(
		SELECT price, date, comments,
		[Store]	=	(SELECT storeId, address, storeName, contactName, phoneNumber, website FROM vwStore s WHERE s.storeId = si.storeId FOR JSON PATH),
		[Item]	=	(SELECT	i.itemId, i.itemName, i.itemDescription, i.avgPrice,
						[brand] = (SELECT brandId, brandName, brandDescription FROM vwBrand WHERE brandId = i.brandId FOR JSON PATH),
						[itemType] = (SELECT itemTypeId, itemTypeName, itemTypeDescription FROM vwItemType WHERE itemTypeId = i.itemTypeId FOR JSON PATH)
					FROM vwItem i
					WHERE i.itemId = si.itemId
					FOR JSON PATH)  
		FROM storeItem si
		WHERE si.userId = @userId
		FOR JSON PATH
	) FOR XML PATH('')
END

GO

/*************************************************************************************************
	
	Name:		spGet_ItemsByBrand
	Purpose:	Lists all items that a given brand has
	Written:	5/7/2020
	Author:		John Murray
	Returns:	JSON list of items with a common brand

**************************************************************************************************/

CREATE PROCEDURE spGet_ItemsByBrand
	@brandId	INT
AS
BEGIN
	SELECT(
		SELECT	i.itemId, i.itemName, i.itemDescription, i.avgPrice,
				[itemType] = (SELECT itemTypeId, itemTypeName, itemTypeDescription FROM vwItemType WHERE itemTypeId = i.itemTypeId FOR JSON PATH)
		FROM vwBrand b
		JOIN vwItem i ON i.brandId = b.brandId
		WHERE b.brandId = @brandId
		FOR JSON PATH
	) FOR XML PATH('')
END

GO


/*************************************************************************************************
	
	Name:		spGet_UsersByStore
	Purpose:	Lists all users who have contributed to a given store
	Written:	5/7/2020
	Author:		John Murray
	Returns:	JSON list users who contributed to a certain store

**************************************************************************************************/

CREATE PROCEDURE spGet_UsersByStore
	@storeId	INT
AS
BEGIN
	SELECT(
		SELECT DISTINCT u.userId, u.firstName, u.lastName, u.userName, u.email, u.goodLoginCount, u.badLoginCount
		FROM vwStore s
		JOIN StoreItem si	ON si.storeId = s.storeId
		JOIN vwUser u		ON u.userId = si.userId
		WHERE s.storeId = @storeId 
		FOR JSON PATH
	) FOR XML PATH('')
END

GO

/*************************************************************************************************
	
	Name:		spGet_StoreWithCheapestPrice
	Purpose:	Given an item, find what store sells the item for the cheapest price
	Written:	5/7/2020
	Author:		John Murray
	Returns:	JSON of store that sells the item for the cheapest price

**************************************************************************************************/

CREATE PROCEDURE spGet_StoreWithCheapestPrice
	@itemId	INT
AS
BEGIN
	SELECT(
		SELECT TOP(1) s.storeId, s.storeName
		FROM StoreItem si
		JOIN vwStore s	ON s.storeId = si.storeId
		ORDER BY si.price
		FOR JSON PATH
	) FOR XML PATH('')
END

GO


/*************************************************************************************************
	
	Name:		spGet_ItemsByDates
	Purpose:	Given an a start date and end date, list items added to database within that time frame
	Written:	5/7/2020
	Author:		John Murray
	Returns:	JSON of items added to database within time fame

**************************************************************************************************/

CREATE PROCEDURE spGet_ItemsByDates 
	@startDate	DATE,
	@endDate	DATE
AS
BEGIN
	SELECT(
		SELECT si.itemId, si.storeId, si.userId, si.price, si.date, i.itemName
		FROM StoreItem si
		JOIN vwItem i	ON i.itemId = si.itemId
		WHERE si.date BETWEEN @startDate AND @endDate
		FOR JSON PATH
	) FOR XML PATH('')
END

GO


/*************************************************************************************************
	
	Name:		spGet_CheapestItems
	Purpose:	List items by avg price in order from cheap to expensive
	Written:	5/8/2020
	Author:		Joe Faflik
	Returns:	JSON of items sorted by price (ascending)

**************************************************************************************************/
CREATE PROCEDURE spGet_CheapestItems
AS
BEGIN
	SELECT (
		SELECT *
		FROM vwItem
		ORDER BY avgPrice
		FOR JSON PATH
	) FOR XML PATH('')
END
GO


/*************************************************************************************************
	
	Name:		spGet_ExpensiveItems
	Purpose:	List items by avg price in order from highest to lowest
	Written:	5/8/2020
	Author:		Joe Faflik
	Returns:	JSON of items sorted by price (descending)

**************************************************************************************************/
CREATE PROCEDURE spGet_ExpensiveItems
AS
BEGIN
	SELECT (
		SELECT *
		FROM Item
		WHERE isDeleted = 0
		ORDER BY avgPrice DESC
		FOR JSON PATH
	) FOR XML PATH('')
END
GO


/*************************************************************************************************
	
	Name:		spCheckSuspiciousLoginCount
	Purpose:	Checks good/bad login counts to check for suspicious activity
	Written:	5/8/2020
	Author:		Joe Faflik
	Returns:	JSON of userId, email, and badLoginCount for badLoginCounts over 100

**************************************************************************************************/
CREATE PROCEDURE spCheckSuspiciousLoginCount
AS
BEGIN
	SELECT (
		SELECT userId, email, badLoginCount 
		FROM [User]
		WHERE badLoginCount > 100
		FOR JSON PATH
	) FOR XML PATH('')
END
GO


/*************************************************************************************************
	
	Name:		spListDeletedUsers
	Purpose:	Lists the users that have been soft-deleted
	Written:	5/8/2020
	Author:		Joe Faflik
	Returns:	JSON of users' firstName, lastName, userName, and email

**************************************************************************************************/
CREATE PROCEDURE spListDeletedUsers
AS
BEGIN
	SELECT (
		SELECT firstName, lastName, userName, email
		FROM [User]
		WHERE isDeleted = 1
		FOR JSON PATH
	) FOR XML PATH('')
END
GO


/*************************************************************************************************
	
	Name:		spListDeletedItems
	Purpose:	Lists the items that have been soft-deleted
	Written:	5/8/2020
	Author:		Joe Faflik
	Returns:	JSON of the items' itemId and itemName 

**************************************************************************************************/
CREATE PROCEDURE spListDeletedItems
AS
BEGIN
	SELECT (
		SELECT itemId, itemName
		FROM Item
		WHERE isDeleted = 1
		FOR JSON PATH
	) FOR XML PATH('')
END
GO


/*************************************************************************************************
	
	Name:		spListDeletedBrands
	Purpose:	Lists the brands that have been soft-deleted
	Written:	5/8/2020
	Author:		Joe Faflik
	Returns:	JSON of the brands' itemId and itemName 

**************************************************************************************************/
CREATE PROCEDURE spListDeletedBrands
AS
BEGIN
	SELECT (
		SELECT brandId, brandName
		FROM Brand
		WHERE isDeleted = 1
		FOR JSON PATH
	) FOR XML PATH('')
END
GO


/*************************************************************************************************
	
	Name:		spGet_StoreItemCount
	Purpose:	Given a storeId, counts how many items are attributed to the store in the database
	Written:	5/8/2020
	Author:		Joe Faflik
	Returns:	JSON of the count of items attributed to @storeId

**************************************************************************************************/
CREATE PROCEDURE spGetStoreItemCount
	@storeId	INT
AS
BEGIN
	SELECT (
		SELECT COUNT(*) AS storeItemsInStore
		FROM StoreItem
		WHERE storeId = @storeId
		FOR JSON PATH
	)FOR XML PATH('')
END
GO


/*************************************************************************************************
	
	Name:		spListRelevantItems
	Purpose:	Given an itemId, list all items with the same itemType
	Written:	5/8/2020
	Author:		Joe Faflik
	Returns:	JSON of items with the same itemType as the item with the given @itemId

**************************************************************************************************/
CREATE PROCEDURE spListRelevantItems
	@itemId		INT
AS
BEGIN
	SELECT (
		SELECT	i.itemId, i.itemName, it.itemTypeName
		FROM Item i JOIN itemType it on i.itemTypeId = it.itemTypeId
		WHERE i.itemTypeId = (SELECT itemTypeId FROM Item WHERE itemId = @itemId)
		FOR JSON PATH
	) FOR XML PATH('')
END
GO


/*************************************************************************************************
	
	Name:		spListStoresByBrand
	Purpose:	List all the stores that carry a given brand
	Written:	5/8/2020
	Author:		Joe Faflik
	Returns:	JSON list of stores that carry a given brand

**************************************************************************************************/
CREATE PROCEDURE spListStoresByBrand
	@brandId	INT
AS
BEGIN
	SELECT (
		SELECT	s.storeId, s.storeName, b.brandName AS carriedBrand
		FROM	Store s		JOIN		StoreItem si ON s.storeId = si.storeId
							JOIN		Item	  i  ON si.itemId = i.itemId
							JOIN		Brand	  b	 ON i.brandId = b.brandId
		WHERE b.brandId = @brandId
		FOR JSON PATH
	) FOR XML PATH('')
END
GO


/*************************************************************************************************
	
	Name:		spListBrandsByStore
	Purpose:	List all the brands that a given store carries
	Written:	5/8/2020
	Author:		Joe Faflik
	Returns:	JSON list of brands that a given store carries

**************************************************************************************************/
CREATE PROCEDURE spListBrandsByStore
	@storeId	INT
AS
BEGIN
	SELECT (
		SELECT	DISTINCT b.brandId, b.brandName, s.storeName as Carrier
		FROM	Store s		JOIN		StoreItem si ON s.storeId = si.storeId
							JOIN		Item	  i  ON si.itemId = i.itemId
							JOIN		Brand	  b	 ON i.brandId = b.brandId
		WHERE s.storeId = @storeId
		FOR JSON PATH
	) FOR XML PATH('')
END
GO






/*
==================================================================================================

									DATA INSERTION AND TESTS

==================================================================================================
*/

-- Test spAddUpdateDelete_User
EXEC spAddUpdateDelete_User 0, 'John', 'Doe', 'cooluserName', 'johndoe@gmail.com', 'coolpassword024'																-- ADD (should return >= 1)
EXEC spAddUpdateDelete_User 0, 'Jane', 'Doe', 'jane_doe', 'jane@gmail.com', 'ijofqwoijwqf'
EXEC spAddUpdateDelete_User 0, 'David', 'Smith', 'smithguy', 'iusemyspace@myspace.com', 'iWillForgetThis'
EXEC spAddUpdateDelete_User 0, 'Goliath', 'Richardson', 'cooluserName', 'ahhhhh@yahoo.com', 'ahhhghehgh123'
EXEC spAddUpdateDelete_User 0, 'Banned', 'Dude', 'helloIAmDeleted', 'deletedguy@gmail.com', 'deletedd'
EXEC spAddUpdateDelete_User 0, 'Charles', 'Obama', 'mrpresident', 'obama@us.gov',  'hmMmMmm8777'
EXEC spAddUpdateDelete_User 0, 'John', 'Smith', 'smithjohn420', 'jonnyboy@gmail.com', 'password'
SELECT * FROM [User]
EXEC spAddUpdateDelete_User 7, 'Johnny Boy', 'Smithenberger', 'jonnyguy', 'jontron@gmail.com', ''																	-- UPDATE (should return >= 1)
SELECT * FROM [User]
EXEC spAddUpdateDelete_User 7, '', '', '', '', '', 1;																												-- DELETE (should return 0)
SELECT * FROM [User] 
EXEC spAddUpdateDelete_User 5, 'Charles', 'Obama', 'mrpresident', 'jane@gmail.com', ''																				-- Test breaking the system (should return -1)


-- Test spAddUpdateDelete_Store
EXEC spAddUpdateDelete_Store 0, '701 E Spring St, Oxford, OH 45056', 'Brick & Ivy Campus Store', '', '(513) 529-2600', 'https://campusstore.miamioh.edu/'			-- ADD
EXEC spAddUpdateDelete_Store 0, '300 S Locust St, Oxford, OH 45056', 'Kroger', '', '(513) 523-2201', 'https://www.kroger.com/stores/details/014/00412?cid=loc_01400412_gmb'
EXEC spAddUpdateDelete_Store 0, '5720 College Corner Pike, Oxford, OH 45056', 'Walmart Supercenter', '', '(513) 524-4122', 'https://www.walmart.com/store/2275/oxford-oh/details'
EXEC spAddUpdateDelete_Store 0, '900 E High St, Oxford, OH 45056', 'Dorsey Market', '', 'N/A', 'N/A'
EXEC spAddUpdateDelete_Store 0,'100 Shakedown Street, Jerry Garcia, CA 43020', 'Grateful Dead Gift Shop', 'Jerry''s ghost', '1-800-432-1493', 'gratefuldead.com';	
SELECT * FROM Store;
EXEC spAddUpdateDelete_Store 5, '2 Dead Boulevard, Jerry Garcia, CA 43020', 'Grateful Dead Gift Shop', 'Jerry''s ghost', '1-800-432-1493', 'gratefuldead.com';		-- UPDATE
SELECT * FROM Store;
EXEC spAddUpdateDelete_Store 5, '', '', '', '', '', 1;																												-- DELETE
SELECT * FROM Store;



-- Test spAddUpdateDelete_Brand																																		-- ADD
EXEC spAddUpdateDelete_Brand 0, 'Nike', 'Sports brand company known for shoes n stuff.'
EXEC spAddUpdateDelete_Brand 0,	'Lays', 'Food company, makes good BBQ chips.'
EXEC spAddUpdateDelete_Brand 0,	'Apple', 'Cool indie company that makes phones or something.'
EXEC spAddUpdateDelete_Brand 0,	'Generic Brand Chips', 'Made up company.'
EXEC spAddUpdateDelete_Brand 0,	'Coca-Cola', 'I like this drink very nice.'

SELECT * FROM Brand
EXEC spAddUpdateDelete_Brand 1, 'Adidas', 'three stripe gang'																										-- UPDATE

SELECT * FROM Brand

EXEC spAddUpdateDelete_Brand 0, 'Bad Brand', 'This brand sucks so we''re deleting it'																				-- DELETE
EXEC spAddUpdateDelete_Brand 6, '', '', 1

SELECT * FROM Brand

-- Test spAddUpdateDelete_ItemType
EXEC spAddUpdateDelete_ItemType 0, 'Food', 'Fresh, frozen, anything etible'																							-- ADD
EXEC spAddUpdateDelete_ItemType 0, 'Clothing', 'Shoes, socks, pants, shirts, etc'
EXEC spAddUpdateDelete_ItemType 0, 'Entertainment', 'Toys, gadgets, fun'
EXEC spAddUpdateDelete_ItemType 0, 'Technology', 'Includes phones/computers/idk'

SELECT * FROM ItemType	
EXEC spAddUpdateDelete_ItemType 1, 'Not Food', 'Definitely not food'																								-- UPDATE

SELECT * FROM ItemType	

EXEC spAddUpdateDelete_ItemType 0, 'Dumb Category', 'Delete this'																									-- DELETE
EXEC spAddUpdateDelete_ItemType 4, '', '', 1;

SELECT * FROM ItemType




-- Test spAddUpdateDelete_Item
EXEC spAddUpdateDelete_Item 0, 1, 2, 'Nike Shoe', 'Cool shoe by Nike'																								-- ADD 
EXEC spAddUpdateDelete_Item 0, 2, 1, 'BBQ Lays Chips', 'The best flavor of chips'
EXEC spAddUpdateDelete_Item 0, 2, 1, 'Original Lays Chips', 'Ehh kinda flavor chips'
EXEC spAddUpdateDelete_Item 0, 5, 1, 'Cherry Coca-Cola', 'Very good flavor, would recommend'
EXEC spAddUpdateDelete_Item 0, 3, 4, 'Apple Watch', 'Used to tell time.'
EXEC spAddUpdateDelete_Item 0, 1, 0, 'This should return -1', 'It should...'																						-- Should return -1

SELECT * FROM Item;
																																									-- UPDATE
EXEC spAddUpdateDelete_Item 1, 1, 2, 'Adidas Shoe', 'Cool shoe by Adidas'	
EXEC spAddUpdateDelete_Item 1, 0, 1, 'This should return -1', 'Should return -1'

SELECT * FROM Item;																																					

EXEC spAddUpdateDelete_Item 3, 0, 0, '', '', 1																														-- DELETE
EXEC spAddUpdateDelete_StoreItem 0, 2, 1, 1, 1.69, '2020-05-07 23:06:22.983', 'Nice'																				-- soft
EXEC spAddUpdateDelete_Item 2, 0, 0, '', '', 1


-- spAddUpdateDelete_StoreItem and trigger tests
EXEC spAddUpdateDelete_StoreItem 0, 1, 1, 1, 1.69, '2020-05-07 23:06:22.983', 'Nice'
EXEC spAddUpdateDelete_StoreItem 0, 1, 1, 1, 2.45, '2020-05-07 23:06:22.983', 'Nice'
SELECT * FROM StoreItem																																				-- avgPrice for Item 1 should be 2.07
SELECT * FROM Item

EXEC spAddUpdateDelete_StoreItem 3, 0, 0, 0, 0, '', '', 1
SELECT * FROM StoreItem																																				-- avgPrice for Item 1 should be 1.69
SELECT * FROM Item;



EXEC spAddUpdateDelete_StoreItem 2, 1, 1, 1, 4.00, '2020-05-07 23:06:22.983', 'Nice'																				-- avgPrice for Item 1 should be 4.00
SELECT * FROM StoreItem;
SELECT * FROM Item

-- Confirm user 1's email
DECLARE @tokenConfirm char(10)
SELECT @tokenConfirm = token
FROM UserRegistration
WHERE userId = 1

-- Confirm user email with token
EXEC spConfirm_Email 1, @tokenConfirm;

-- Get Items from Brick & Ivy
EXEC spGet_StoreItemsByStore 1;

-- Get stores that sell Adidas Shoe
EXEC spGet_StoresByItem 1;

-- Get items less than or equal to 10$
EXEC spGet_StoreItemsByPrice 10.00;

-- Get list of all stores
EXEC spGet_ListStores;

-- Get list of all brands
EXEC spGet_Brands;

-- Get list of all users
EXEC spGet_Users;

-- Get list of all items
EXEC spGet_ListItems;

-- Get all items by User 1
EXEC spGet_StoreItemsByUser 1;

-- Get all items from Nike
EXEC spGet_ItemsByBrand 1;

-- Get users that have posted for Brick & Ivy
EXEC spGet_UsersByStore 1;

-- Get store with cheapest Adidas Shoes
EXEC spGet_StoreWithCheapestPrice 1;

-- Get items submitted from these dates
EXEC spGet_ItemsByDates '2020-05-06', '2020-05-08';

-- Get cheapest items
EXEC spGet_CheapestItems;

-- Get expensive items
EXEC spGet_ExpensiveItems;

-- Check for suspicious login count
EXEC spCheckSuspiciousLoginCount;

-- List soft deleted users
EXEC spListDeletedUsers;

-- List soft deleted items
EXEC spListDeletedItems;

-- List soft deleted brands
EXEC spListDeletedBrands;

-- Get the number of StoreItems in a store w/ storeId
EXEC spGetStoreItemCount 1;

-- List relevant items (with same itemType) given a itemId
EXEC spListRelevantItems 3;

-- Given a brandId, list stores that carry the brand
EXEC spListStoresByBrand 2;

-- Given a storeId, list brands in the store
EXEC spListBrandsByStore 2;

-- Make user
EXEC spAddUpdateDelete_User 0, 'test', 'tess', 'testts', 'test@yahoo.com', 'testq';
EXEC spReset_RegistrationToken 7;

-- Try to login user before confirming email
EXEC spLogin 7, 'testq';

DECLARE @tokenVar char(10)
SELECT @tokenVar = token
FROM UserRegistration
WHERE userId = 7

-- Confirm user email with token
EXEC spConfirm_Email 7, @tokenVar;

-- Login user after confirming email
EXEC spLogin 7, 'testq';

-- Reset the users password
EXEC spReset_Password 7;

DECLARE @tokenVarP char(30)
SELECT @tokenVarP = token
FROM PasswordReset
WHERE userId = 7

EXEC spConfirm_PasswordReset 7, @tokenVarP, 'testNewPass'

EXEC spLogin 7, 'testNewPass';

-- User 7 now has 2 good login counts, 1 bad login count
select * from [User]


-- Delete everything
GO

EXEC sp_MSForEachTable 'DISABLE TRIGGER ALL ON ?'
GO
EXEC sp_MSForEachTable 'ALTER TABLE ? NOCHECK CONSTRAINT ALL'
GO
EXEC sp_MSForEachTable 'DELETE FROM ?'
GO
EXEC sp_MSForEachTable 'ALTER TABLE ? CHECK CONSTRAINT ALL'
GO
EXEC sp_MSForEachTable 'ENABLE TRIGGER ALL ON ?'

GO

