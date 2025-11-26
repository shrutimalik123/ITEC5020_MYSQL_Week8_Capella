-- ITEC 5020: FINAL DATABASE SCRIPT (Week 8)
-- Project: Hypotify Clinical Insights Bot
-- Target Database: artificial_emr

-- -----------------------------------------------------
-- 1. DATABASE SETUP AND SCHEMA CREATION (3NF Model)
-- -----------------------------------------------------

-- Ensure old test data is safely deleted and use the final database
DROP DATABASE IF EXISTS artificial_emr;
CREATE DATABASE artificial_emr;
USE artificial_emr;

-- Table 1: PATIENT (Master Data)
CREATE TABLE PATIENT (
    PatientID VARCHAR(50) PRIMARY KEY,
    PatientGender VARCHAR(10) NOT NULL,
    PatientDateOfBirth DATE,
    PatientRace VARCHAR(50),
    PatientMaritalStatus VARCHAR(20),
    PatientLanguage VARCHAR(20),
    PatientPopulationPercentageBelowPoverty DECIMAL(5, 2)
);

-- Table 2: ADMISSION (Links to PATIENT)
CREATE TABLE ADMISSION (
    AdmissionID INT PRIMARY KEY,
    PatientID VARCHAR(50) NOT NULL,
    AdmissionStartDate DATETIME,
    AdmissionEndDate DATETIME,
    FOREIGN KEY (PatientID) REFERENCES PATIENT(PatientID)
);

-- Table 3: DIAGNOSIS (Links to ADMISSION)
-- We use a surrogate key for cleaner management, as required by the 3NF design.
CREATE TABLE DIAGNOSIS (
    DiagnosisRecordID INT PRIMARY KEY AUTO_INCREMENT,
    PatientID VARCHAR(50) NOT NULL, -- Included from CSV file for data completeness
    AdmissionID INT NOT NULL,
    PrimaryDiagnosisCode VARCHAR(10) NOT NULL,
    PrimaryDiagnosisDescription VARCHAR(255),
    FOREIGN KEY (AdmissionID) REFERENCES ADMISSION(AdmissionID)
);

-- Table 4: LAB_OBSERVATION (Links to ADMISSION)
-- Uses BIGINT to accommodate the full 107,535,387 lab records in the project scope.
CREATE TABLE LAB_OBSERVATION (
    LabRecordID BIGINT PRIMARY KEY AUTO_INCREMENT,
    PatientID VARCHAR(50) NOT NULL, -- Included from CSV file for data completeness
    AdmissionID INT NOT NULL,
    LabName VARCHAR(100) NOT NULL,
    LabValue DECIMAL(10, 3),
    LabUnits VARCHAR(20),
    LabDateTime DATETIME,
    FOREIGN KEY (AdmissionID) REFERENCES ADMISSION(AdmissionID)
);

-- -----------------------------------------------------
-- 2. DATA IMPORT COMMANDS (LOAD DATA INFILE)
--
-- INSTRUCTIONS: Run these commands in MySQL Workbench.
-- YOU MUST REPLACE THE PLACEHOLDER PATH (C:/path/to/...) with the actual
-- file path on your computer where the CSV files are located.
-- -----------------------------------------------------

-- Note: We are loading files in Parent -> Child order for FK integrity.

-- Load 1: PATIENT (Parent Table)
-- Loads approximately 500 patient records
LOAD DATA INFILE 'C:/path/to/PatientCorePopulatedTable.csv'
INTO TABLE PATIENT
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- Load 2: ADMISSION (Child of Patient)
-- Loads approximately 1,000 admission records
LOAD DATA INFILE 'C:/path/to/AdmissionsCorePopulatedTable.csv'
INTO TABLE ADMISSION
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- Load 3: DIAGNOSIS (Child of Admission)
-- Loads approximately 1,000 diagnosis records
-- Note: The CSV does not have DiagnosisRecordID, so AUTO_INCREMENT is used.
LOAD DATA INFILE 'C:/path/to/AdmissionsDiagnosesCorePopulatedTable.csv'
INTO TABLE DIAGNOSIS
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(@dummy, PatientID, AdmissionID, PrimaryDiagnosisCode, PrimaryDiagnosisDescription)
SET PatientID = PatientID, AdmissionID = AdmissionID, PrimaryDiagnosisCode = PrimaryDiagnosisCode, PrimaryDiagnosisDescription = PrimaryDiagnosisDescription;

-- Load 4: LAB_OBSERVATION (Child of Admission)
-- Loads approximately 8,900 lab observation records
-- Note: The CSV does not have LabRecordID, so AUTO_INCREMENT is used.
LOAD DATA INFILE 'C:/path/to/LabsCorePopulatedTable.csv'
INTO TABLE LAB_OBSERVATION
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(@dummy, PatientID, AdmissionID, LabName, LabValue, LabUnits, LabDateTime)
SET PatientID = PatientID, AdmissionID = AdmissionID, LabName = LabName, LabValue = LabValue, LabUnits = LabUnits, LabDateTime = LabDateTime;

-- -----------------------------------------------------
-- 3. POST-IMPORT VERIFICATION (Data Count Checks)
-- -----------------------------------------------------

SELECT 'PATIENT COUNT' AS Table_Name, COUNT(*) FROM PATIENT;
SELECT 'ADMISSION COUNT' AS Table_Name, COUNT(*) FROM ADMISSION;
SELECT 'DIAGNOSIS COUNT' AS Table_Name, COUNT(*) AS Record_Count FROM DIAGNOSIS;
SELECT 'LAB_OBSERVATION COUNT' AS Table_Name, COUNT(*) FROM LAB_OBSERVATION;

-- -----------------------------------------------------
-- 4. DATABASE ACCURACY AND PERFORMANCE TESTING
-- (As described in the Week 8 reflection)
-- -----------------------------------------------------

-- ACCURACY TEST 1: REFERENTIAL INTEGRITY CHECK (Conceptual Test)
-- This query confirms that the Foreign Key constraint is working by ensuring every admission
-- in the diagnosis table has a matching record in the admission table. (Should return 0 rows).
SELECT D.AdmissionID
FROM DIAGNOSIS D
LEFT JOIN ADMISSION A ON D.AdmissionID = A.AdmissionID
WHERE A.AdmissionID IS NULL;

-- ACCURACY TEST 2: DATA TYPE INTEGRITY (Sample check for LabValue)
-- Checks for non-numeric LabValues where a calculation is expected.
SELECT LabRecordID, LabValue
FROM LAB_OBSERVATION
WHERE LabValue IS NOT NULL AND LabValue REGEXP '[^0-9\.]'
LIMIT 5;

-- PERFORMANCE TEST 1: MULTI-JOIN COHORT RETRIEVAL (AI Chatbot Core Function)
-- Retrieves all high glucose lab values for a specific demographic ('African American').
-- This tests the speed of the 3NF joins across three tables.
SELECT
    P.PatientID,
    L.LabName,
    L.LabValue,
    A.AdmissionStartDate
FROM PATIENT P
JOIN ADMISSION A ON P.PatientID = A.PatientID
JOIN LAB_OBSERVATION L ON A.AdmissionID = L.AdmissionID
WHERE P.PatientRace = 'African American' AND L.LabName = 'METABOLIC: GLUCOSE' AND L.LabValue > 150
ORDER BY L.LabDateTime DESC
LIMIT 10;