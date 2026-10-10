


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