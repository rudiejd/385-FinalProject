
/***********************************************************************************************
	
	Authors:			JD Rudie, Joe Faflik, John Murray
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
	itemTypeId				INT				NOT NULL	PRIMARY KEY		IDENTITY,
	itemTypeName			VARCHAR(50)		NOT NULL,
	itemTypeDescription		VARCHAR(200)	NOT NULL
)

CREATE TABLE Brand(
	brandId					INT				NOT NULL	PRIMARY KEY		IDENTITY,
	brandName				VARCHAR(50)		NOT NULL,
	brandDescription		VARCHAR(200)	NOT NULL,
	isDeleted				BIT				NOT NULL
)

CREATE TABLE Item(
	itemId					INT				NOT NULL	PRIMARY KEY		IDENTITY,
	brandId					INT				NOT NULL	FOREIGN KEY REFERENCES Brand(brandId),
	itemTypeId				INT				NOT NULL	FOREIGN KEY REFERENCES ItemType(itemTypeId),
	itemName				VARCHAR(50)		NOT NULL,
	itemDescription			VARCHAR(200)	NOT NULL,
	isDeleted				BIT				NOT NULL
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
	userId					INT				NOT NULL	PRIMARY KEY		IDENTITY,
	isActive				BIT				DEFAULT 0	NOT NULL,
	token					CHAR(10)
)

CREATE TABLE StoreItem(
	itemId					INT				NOT NULL,
	storeId					INT				NOT NULL,
	userId					INT				NOT NULL	FOREIGN KEY REFERENCES [User](userId),
	price					MONEY			NOT NULL,
	[date]					DATE			NOT NULL,
	comments				VARCHAR(200)	NOT NULL,
	PRIMARY KEY (itemId, storeId)
)

CREATE TABLE Store(
	storeId					INT				NOT NULL	PRIMARY KEY		IDENTITY,
	[address]				VARCHAR(200)	NOT NULL,
	storeName				VARCHAR(100)	NOT NULL,
	contactName				VARCHAR(50)		NOT NULL,
	phoneNumber				VARCHAR(20)		NOT NULL,
	website					VARCHAR(200)	NOT NULL
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

-- Add to Store
SET IDENTITY_INSERT Store ON
INSERT INTO Store (storeId, address, storeName, contactName, phoneNumber, website)
	VALUES	(1, '701 E Spring St, Oxford, OH 45056', 'Brick & Ivy Campus Store', '', '(513) 529-2600', 'https://campusstore.miamioh.edu/'),
			(2, '300 S Locust St, Oxford, OH 45056', 'Kroger', '', '(513) 523-2201', 'https://www.kroger.com/stores/details/014/00412?cid=loc_01400412_gmb'),
			(3, '5720 College Corner Pike, Oxford, OH 45056', 'Walmart Supercenter', '', '(513) 524-4122', 'https://www.walmart.com/store/2275/oxford-oh/details'),
			(4, '900 E High St, Oxford, OH 45056', 'Dorsey Market', '', 'N/A', 'N/A')
SET IDENTITY_INSERT Store OFF


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


-- Add to StoreItem
INSERT INTO StoreItem (itemId, storeId, userId, price, date, comments)
	VALUES	(1, 1, 1, 19.99, '3-7-2020', 'ayyo i found this cool pair o nike shoes'),
			(1, 2, 1, 17.98, '4-2-2020', 'also nike shoes'),
			(2, 3, 2, 4.98, '4-3-2020', 'COOL CHIPS'),
			(4, 3, 4, 1.15, '4-23-2020', ''),
			(4, 2, 4, 0.98, '4-26-2020', 'ijqwfijqwfd'),
			(4, 1, 3, 1.30, '4-29-2020', 'mmm'),
			(4, 4, 5, 1.10, '5-1-2020', ': )')

/*
SELECT * FROM [User]
SELECT * FROM Store
SELECT * FROM StoreItem
SELECT * FROM Item
SELECT * FROM ItemType
SELECT * FROM Brand
*/