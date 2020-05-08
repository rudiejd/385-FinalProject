
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

DROP DATABASE IF EXISTS StoreDb;

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
	isActive				BIT				NOT NULL	DEFAULT SUBSTRING(REPLACE(newid(), '-', ''), 1, 10),
	regDate					DATETIME		NOT NULL	DEFAULT	GETDATE(),
	token					CHAR(10)
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
	
	Name:		update_AvgItemPrice
	Purpose:	Updates average item price after a new StoreItem is inserted, updated, or deleted
	Written:	5/7/2020
	Author:		JD Rudie

**************************************************************************************************/
CREATE TRIGGER update_AvgItemPrice
ON StoreItem AFTER INSERT, UPDATE, DELETE AS
BEGIN
	DECLARE @price MONEY, @itemId INT
	IF EXISTS (SELECT TOP(1) NULL FROM deleted) BEGIN
		DECLARE delCur CURSOR FOR (SELECT price, itemId FROM inserted)

		OPEN delCur
		FETCH NEXT FROM delCur
		INTO @price, @itemId

		WHILE @@FETCH_STATUS = 0
		BEGIN

			UPDATE Item SET avgPrice = ( (SELECT avgPrice FROM Item WHERE itemId = @itemid) - @price ) / ( (SELECT COUNT(*) FROM StoreItem WHERE itemId = @itemId) )
			WHERE itemid = @itemId
			FETCH NEXT FROM insCur
			INTO @price, @itemId
		END

		CLOSE insCur
		DEALLOCATE insCur;
	END ELSE BEGIN
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
			END ELSE BEGIN																					-- hard
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
	@brandName				INT,
	@brandDescription		DATETIME,
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
	@itemTypeName			INT,
	@itemTypeDescription	DATETIME,
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
	@itemName			MONEY,
	@itemDescription	DATETIME,
	@delete				BIT = 0
AS BEGIN
BEGIN TRAN
	BEGIN TRY 
		IF(@itemId = 0) BEGIN																				-- ADD
			IF(NOT EXISTS (SELECT NULL FROM Brand WHERE brandId = @brandId) OR NOT EXISTS(SELECT NULL FROM ItemType WHERE itemTypeId = @itemTypeId)) BEGIN
				SELECT -1
			END
			ELSE BEGIN
				INSERT INTO Item (itemId, brandId, itemTypeId, itemName, itemDescription)
				VALUES (@itemId, @brandId, @itemTypeId, @itemName, @itemDescription)
				
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






/*
==================================================================================================

									DATA INSERTION AND TESTS

==================================================================================================
*/

-- Add to User
SET IDENTITY_INSERT [User] ON
INSERT INTO [User] (userId, firstName, lastName, userName, email, password, goodLoginCount, badLoginCount, isDeleted)
	VALUES	(1, 'John', 'Doe', 'cooluserName', 'johndoe@gmail.com', HASHBYTES('SHA2_512', 'coolpassword024'), 178, 27, 0),
			(2, 'Jane', 'Doe', 'jane_doe', 'jane@gmail.com', HASHBYTES('SHA2_512', 'ijofqwoijwqf'), 257, 12, 0),
			(3, 'David', 'Smith', 'smithguy', 'iusemyspace@myspace.com', HASHBYTES('SHA2_512', 'iWillForgetThis'), 3, 1, 0),
			(4, 'Goliath', 'Richardson', 'cooluserName', 'ahhhhh@yahoo.com', HASHBYTES('SHA2_512', 'ahhhghehgh123'), 13, 0, 0),
			(5, 'Banned', 'Dude', 'helloIAmDeleted', 'deletedguy@gmail.com', HASHBYTES('SHA2_512', 'deletedd'), 132, 56, 1),
			(6, 'Charles', 'Obama', 'mrpresident', 'obama@us.gov', HASHBYTES('SHA2_512', 'hmMmMmm8777'), 46, 2, 0)
SET IDENTITY_INSERT [User] OFF

-- Test spAddUpdateDelete_User
EXEC spAddUpdateDelete_User 0, 'John', 'Smith', 'smithjohn420', 'jonnyboy@gmail.com', 'password';																-- Should return 7 (new userId after insertions)
SELECT * FROM [User]
EXEC spAddUpdateDelete_User 7, 'Johnny Boy', 'Smithenberger', 'jonnyguy', 'jontron@gmail.com', '';																-- Should return 7 (userId) and user should be updated
SELECT * FROM [User]
EXEC spAddUpdateDelete_User 7, '', '', '', '', '', 1;																												-- Should return 0 and user should be deleted
SELECT * FROM [User] 
EXEC spAddUpdateDelete_User 5, 'Charles', 'Obama', 'mrpresident', 'jane@gmail.com', '';																			-- Should return -1

-- Add to Store
SET IDENTITY_INSERT Store ON
INSERT INTO Store (storeId, address, storeName, contactName, phoneNumber, website)
	VALUES	(1, '701 E Spring St, Oxford, OH 45056', 'Brick & Ivy Campus Store', '', '(513) 529-2600', 'https://campusstore.miamioh.edu/'),
			(2, '300 S Locust St, Oxford, OH 45056', 'Kroger', '', '(513) 523-2201', 'https://www.kroger.com/stores/details/014/00412?cid=loc_01400412_gmb'),
			(3, '5720 College Corner Pike, Oxford, OH 45056', 'Walmart Supercenter', '', '(513) 524-4122', 'https://www.walmart.com/store/2275/oxford-oh/details'),
			(4, '900 E High St, Oxford, OH 45056', 'Dorsey Market', '', 'N/A', 'N/A')
SET IDENTITY_INSERT Store OFF

-- Test spAddUpdateDelete_Store
EXEC spAddUpdateDelete_Store 0,'100 Shakedown Street, Jerry Garcia, CA 43020', 'Grateful Dead Gift Shop', 'Jerry''s ghost', '1-800-432-1493', 'gratefuldead.com';	-- Should return 5 (new storeId after insertion)
SELECT * FROM Store;
EXEC spAddUpdateDelete_Store 5, '2 Dead Boulevard, Jerry Garcia, CA 43020', 'Grateful Dead Gift Shop', 'Jerry''s ghost', '1-800-432-1493', 'gratefuldead.com';		-- Should return 5 (storeId) and store should be updated
SELECT * FROM Store;
EXEC spAddUpdateDelete_Store 5, '', '', '', '', '', 1;																													-- Should return 0 to signify store was deleted
SELECT * FROM Store;



-- Add to Brand
SET IDENTITY_INSERT Brand ON
INSERT INTO Brand (brandId, brandName, brandDescription, isDeleted)
	VALUES	(1, 'Nike', 'Sports brand company known for shoes n stuff.', 0),
			(2, 'Lays', 'Food company, makes good BBQ chips.', 0),
			(3, 'Apple', 'Cool indie company that makes phones or something.', 0),
			(4, 'Generic Brand Chips', 'Made up company.', 1),
			(5, 'Coca-Cola', 'I like this drink very nice.', 0)
SET IDENTITY_INSERT Brand OFF

-- Add to ItemType
SET IDENTITY_INSERT ItemType ON
INSERT INTO ItemType (itemTypeId, itemTypeName, itemTypeDescription)
	VALUES	(1, 'Food', 'Fresh, frozen, anything etible'),
			(2, 'Clothing', 'Shoes, socks, pants, shirts, etc'),
			(3, 'Entertainment', 'Toys, gadgets, fun'),
			(4, 'Technology', 'Includes phones/computers/idk')

SET IDENTITY_INSERT ItemType OFF

-- Add to Item
SET IDENTITY_INSERT Item ON
INSERT INTO Item (itemId, brandId, itemTypeId, itemName, itemDescription, isDeleted)
	VALUES	(1, 1, 2, 'Nike Shoe', 'Cool shoe by Nike', 0),
			(2, 2, 1, 'BBQ Lays Chips', 'The best flavor of chips', 0),
			(3, 2, 1, 'Original Lays Chips', 'Ehh kinda flavor chips', 1),
			(4, 5, 1, 'Cherry Coca-Cola', 'Very good flavor, would recommend', 0),
			(5, 3, 4, 'Apple Watch', 'Used to tell time.', 0)


SET IDENTITY_INSERT Item OFF




-- spAddUpdateDelete_StoreItem and trigger tests
EXEC spAddUpdateDelete_StoreItem 0, 1, 1, 1, 1.69, '2020-05-07 23:06:22.983', 'Nice';
EXEC spAddUpdateDelete_StoreItem 0, 1, 1, 1, 2.45, '2020-05-07 23:06:22.983', 'Nice';
SELECT * FROM StoreItem;
SELECT * FROM Item;