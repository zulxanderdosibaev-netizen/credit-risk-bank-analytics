


            --DDL AND DML

SELECT 
    loan_id,
    borrower_id,
    -- Преобразуем текстовую дату в формат DATE
    TRY_CONVERT(DATE, application_date, 104) AS clean_application_date,
    loan_purpose,
    TRY_CAST(loan_amount AS DECIMAL(12,2)) AS clean_loan_amount,
    TRY_CAST(term_months AS INT) AS clean_term_months,
    days_delinquent,
    defaulted
FROM loan_applications;

SELECT 
    loan_id,
    -- Пробуем привести к числу; если там текст (вроде '13.май'), вернется NULL
    TRY_CAST(interest_rate AS DECIMAL(10,2)) AS clean_interest_rate,
    TRY_CAST(monthly_payment AS DECIMAL(10,2)) AS clean_monthly_payment,
    TRY_CAST(dti_ratio AS DECIMAL(10,2)) AS clean_dti_ratio
FROM loan_applications;

-- 1. Очищаем старые таблицы, если они успели создаться
IF OBJECT_ID('fact_loans', 'U') IS NOT NULL DROP TABLE fact_loans;
IF OBJECT_ID('dim_borrowers', 'U') IS NOT NULL DROP TABLE dim_borrowers;

-- 2. Создаем структуру dim_borrowers с явным NOT NULL на первичный ключ
CREATE TABLE dim_borrowers (
    borrower_id VARCHAR(50) NOT NULL PRIMARY KEY,
    age INT,
    state VARCHAR(50),
    education_level VARCHAR(50),
    employment_status VARCHAR(50),
    years_employed INT,
    annual_income DECIMAL(12,2),
    credit_score INT,
    home_ownership VARCHAR(50),
    dependents INT,
    existing_monthly_debt DECIMAL(12,2)
);

-- Заполняем dim_borrowers
INSERT INTO dim_borrowers
SELECT 
    TRIM(borrower_id),
    TRY_CAST(age AS INT),
    TRIM(state),
    TRIM(education_level),
    TRIM(employment_status),
    TRY_CAST(years_employed AS INT),
    TRY_CAST(annual_income AS DECIMAL(12,2)),
    TRY_CAST(credit_score AS INT),
    TRIM(home_ownership),
    TRY_CAST(dependents AS INT),
    TRY_CAST(existing_monthly_debt AS DECIMAL(12,2))
FROM borrower_profiles
WHERE borrower_id IS NOT NULL;


-- 3. Создаем структуру fact_loans с явными ключами и связью (Foreign Key)
CREATE TABLE fact_loans (
    loan_id VARCHAR(50) NOT NULL PRIMARY KEY,
    borrower_id VARCHAR(50) NOT NULL FOREIGN KEY REFERENCES dim_borrowers(borrower_id),
    application_date DATE,
    loan_purpose VARCHAR(50),
    loan_amount DECIMAL(12,2),
    term_months INT,
    interest_rate DECIMAL(5,2),
    monthly_payment DECIMAL(12,2),
    dti_ratio DECIMAL(5,2),
    loan_status VARCHAR(50),
    days_delinquent INT,
    is_default INT
);

-- Заполняем fact_loans
INSERT INTO fact_loans
SELECT 
    TRIM(loan_id),
    TRIM(borrower_id),
    TRY_CONVERT(DATE, application_date, 104),
    TRIM(loan_purpose),
    TRY_CAST(loan_amount AS DECIMAL(12,2)),
    TRY_CAST(term_months AS INT),
    ISNULL(TRY_CAST(interest_rate AS DECIMAL(5,2)), 12.50),
    TRY_CAST(monthly_payment AS DECIMAL(12,2)),
    ISNULL(TRY_CAST(dti_ratio AS DECIMAL(5,2)), 35.00),
    TRIM(loan_status),
    TRY_CAST(days_delinquent AS INT),
    TRY_CAST(defaulted AS INT)
FROM loan_applications
WHERE loan_id IS NOT NULL 
  AND borrower_id IN (SELECT borrower_id FROM dim_borrowers);

 select *
 from borrower_profiles;

 select *
 from dim_borrowers;

 select *
 from fact_loans;

 select  *
 from loan_applications;