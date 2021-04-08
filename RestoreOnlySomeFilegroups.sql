USE [master]
GO

IF EXISTS (SELECT name FROM sys.databases WHERE name = N'RestoreOnlySomeFilegroups')
	DROP DATABASE [RestoreOnlySomeFilegroups]
GO

CREATE DATABASE [RestoreOnlySomeFilegroups]

ALTER DATABASE [RestoreOnlySomeFilegroups] SET RECOVERY SIMPLE 
GO

ALTER DATABASE [RestoreOnlySomeFilegroups] ADD FILEGROUP [FGReadOnly]
ALTER DATABASE [RestoreOnlySomeFilegroups] ADD FILEGROUP [FGReadWrite]
GO

DECLARE @DefaultDataDir NVARCHAR(4000) 
DECLARE @Query NVARCHAR(4000) 
EXEC xp_instance_regread N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'DefaultData', @DefaultDataDir OUTPUT
IF RIGHT(@DefaultDataDir, 1) <> '\'
	SET @DefaultDataDir += '\'

SET @Query = CONCAT('ALTER DATABASE [RestoreOnlySomeFilegroups] ADD FILE ( NAME = N''FReadOnly'', FILENAME =  N''', @DefaultDataDir,'FReadOnly.ndf'') TO FILEGROUP [FGReadOnly]')
EXEC(@query)

SET @Query = CONCAT('ALTER DATABASE [RestoreOnlySomeFilegroups] ADD FILE ( NAME = N''FReadWrite'', FILENAME =  N''', @DefaultDataDir,'FReadWrite.ndf'') TO FILEGROUP [FGReadWrite]')
EXEC(@query)
GO

USE [RestoreOnlySomeFilegroups]
GO
CREATE PARTITION FUNCTION [PFMixed] (BIT) AS RANGE RIGHT FOR VALUES (1)
GO
CREATE PARTITION SCHEME [PSMixed] AS PARTITION [PFMixed] TO ([FGReadWrite], [FGReadOnly])
GO

CREATE TABLE [TblMixed] 
(
	ID INT NOT NULL, 
	Archived BIT NOT NULL,
	PRIMARY KEY
	(
		ID,
		Archived
	) ON [PSMixed](Archived)
)
GO

INSERT INTO dbo.TblMixed (ID, Archived)
SELECT *
FROM (VALUES (1,1),(2,1),(3,1),(4,1),(5,1),(100,0),(101,0)) Tst (ID, Archived)
GO

ALTER DATABASE [RestoreOnlySomeFilegroups] MODIFY FILEGROUP [FGReadOnly] READONLY
GO

BACKUP DATABASE [RestoreOnlySomeFilegroups] FILEGROUP = 'FGReadOnly' TO DISK = 'RestoreOnlySomeFilegroupsReadOnly.bak' WITH INIT 
GO
BACKUP DATABASE [RestoreOnlySomeFilegroups] READ_WRITE_FILEGROUPS TO DISK = 'RestoreOnlySomeFilegroupsReadWrite.bak' WITH INIT 
GO

INSERT INTO dbo.TblMixed (ID, Archived) VALUES (200,0)
GO

SELECT * FROM dbo.TblMixed
GO

USE [master]
GO
RESTORE DATABASE [RestoreOnlySomeFilegroups] READ_WRITE_FILEGROUPS FROM DISK = 'RestoreOnlySomeFilegroupsReadWrite.bak' WITH PARTIAL, RECOVERY
GO
RESTORE DATABASE [RestoreOnlySomeFilegroups] FILEGROUP = 'FGReadOnly' WITH RECOVERY
GO

USE [RestoreOnlySomeFilegroups]
GO

INSERT INTO dbo.TblMixed (ID, Archived) VALUES (300,0)
GO
SELECT * FROM dbo.TblMixed
GO

USE [master]
GO
DROP DATABASE [RestoreOnlySomeFilegroups]
GO
RESTORE DATABASE [RestoreOnlySomeFilegroups] READ_WRITE_FILEGROUPS FROM DISK = 'RestoreOnlySomeFilegroupsReadWrite.bak' WITH PARTIAL, RECOVERY
GO
RESTORE DATABASE [RestoreOnlySomeFilegroups] FILEGROUP = 'FGReadOnly' FROM DISK = 'RestoreOnlySomeFilegroupsReadOnly.bak' WITH RECOVERY
GO

USE [RestoreOnlySomeFilegroups]
GO

INSERT INTO dbo.TblMixed (ID, Archived) VALUES (400,0)
GO
SELECT * FROM dbo.TblMixed
GO
