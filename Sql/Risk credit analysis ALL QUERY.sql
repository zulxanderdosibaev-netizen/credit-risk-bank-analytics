--select *
--from loan_applications

--select *
--from borrower_profiles

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


                    --Бизнес вопросы
    --1: Общий обзор кредитного портфеля и риск-метрики

SELECT 
    COUNT(*) AS total_loans,
    SUM(loan_amount) AS total_volume,
    AVG(loan_amount) AS avg_loan_amount,
    AVG(interest_rate) AS avg_interest_rate
FROM fact_loans;

    --2: Расчет уровня дефолта (Default Rate)

    SELECT 
    SUM(is_default) AS total_default_loans,
    COUNT(*) AS total_loans,
    ROUND(CAST(SUM(is_default) AS FLOAT) / COUNT(*) * 100, 2) AS default_rate_pct
FROM fact_loans;

    --3: Риск по целям кредита (loan_purpose)

SELECT 
    loan_purpose,
    COUNT(*) AS total_loans,
    SUM(loan_amount) AS total_volume,
    SUM(is_default) AS default_loans,
    ROUND(CAST(SUM(is_default) AS FLOAT) / COUNT(*) * 100, 2) AS default_rate_pct
FROM fact_loans
GROUP BY loan_purpose
ORDER BY default_rate_pct DESC;

    --4:Анализ по категориям кредитного рейтинга (credit_score)

    SELECT 
    CASE 
        WHEN b.credit_score < 600 THEN '1. Poor (<600)'
        WHEN b.credit_score BETWEEN 600 AND 699 THEN '2. Fair (600-699)'
        WHEN b.credit_score BETWEEN 700 AND 749 THEN '3. Good (700-749)'
        WHEN b.credit_score >= 750 THEN '4. Excellent (750+)'
        ELSE 'Unknown'
    END AS credit_score_group,
    COUNT(f.loan_id) AS total_loans,
    AVG(b.annual_income) AS avg_annual_income,
    ROUND(CAST(SUM(f.is_default) AS FLOAT) / COUNT(f.loan_id) * 100, 2) AS default_rate_pct
FROM fact_loans f
JOIN dim_borrowers b ON f.borrower_id = b.borrower_id
GROUP BY 
    CASE 
        WHEN b.credit_score < 600 THEN '1. Poor (<600)'
        WHEN b.credit_score BETWEEN 600 AND 699 THEN '2. Fair (600-699)'
        WHEN b.credit_score BETWEEN 700 AND 749 THEN '3. Good (700-749)'
        WHEN b.credit_score >= 750 THEN '4. Excellent (750+)'
        ELSE 'Unknown'
    END
ORDER BY credit_score_group;

     --5 Влияние коэффициента долговой нагрузки (dti_ratio)

SELECT 
    CASE 
        WHEN dti_ratio < 20.0 THEN 'Low DTI (<20%)'
        WHEN dti_ratio BETWEEN 20.0 AND 40.0 THEN 'Medium DTI (20-40%)'
        WHEN dti_ratio > 40.0 THEN 'High DTI (>40%)'
        ELSE 'Unknown'
    END AS dti_level,
    COUNT(*) AS total_loans,
    ROUND(CAST(SUM(is_default) AS FLOAT) / COUNT(*) * 100, 2) AS default_rate_pct
FROM fact_loans
GROUP BY 
    CASE 
        WHEN dti_ratio < 20.0 THEN 'Low DTI (<20%)'
        WHEN dti_ratio BETWEEN 20.0 AND 40.0 THEN 'Medium DTI (20-40%)'
        WHEN dti_ratio > 40.0 THEN 'High DTI (>40%)'
        ELSE 'Unknown'
    END
ORDER BY default_rate_pct DESC;

   --6 :Топ-5 штатов с наибольшей суммой убытков (дефолтов)

SELECT TOP 5
    b.state,
    COUNT(f.loan_id) AS total_loans,
    SUM(CASE WHEN f.is_default = 1 THEN f.loan_amount ELSE 0 END) AS defaulted_volume,
    ROUND(CAST(SUM(f.is_default) AS FLOAT) / COUNT(f.loan_id) * 100, 2) AS default_rate_pct
FROM fact_loans f
JOIN dim_borrowers b ON f.borrower_id = b.borrower_id
GROUP BY b.state
ORDER BY defaulted_volume DESC;

       --7: Ежемесячный тренд выдач и проблемных кредитов

SELECT 
    YEAR(application_date) AS issue_year,
    MONTH(application_date) AS issue_month,
    COUNT(*) AS total_loans,
    SUM(loan_amount) AS total_volume,
    SUM(CASE WHEN days_delinquent > 30 THEN 1 ELSE 0 END) AS delinquent_over_30_days,
    SUM(is_default) AS total_defaults
FROM fact_loans
GROUP BY YEAR(application_date), MONTH(application_date)
ORDER BY issue_year, issue_month;