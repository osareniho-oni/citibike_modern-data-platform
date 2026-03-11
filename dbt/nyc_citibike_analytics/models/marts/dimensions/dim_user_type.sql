{{
    config(
        materialized='table',
        tags=['marts', 'dimension', 'user_type']
    )
}}

-- Dimension: User Type
-- Grain: 1 row per user type
-- Static dimension with predefined user types

select
    -- Surrogate key
    row_number() over (order by user_type_id) as user_type_key,
    
    -- Natural key
    user_type_id,
    
    -- Descriptive attributes
    user_type_name,
    user_type_description,
    has_subscription,
    
    -- Metadata
    current_timestamp() as created_at,
    current_timestamp() as updated_at

from (
    select
        'member' as user_type_id,
        'Member' as user_type_name,
        'Annual or monthly subscription holder with unlimited rides' as user_type_description,
        true as has_subscription
    
    union all
    
    select
        'casual' as user_type_id,
        'Casual Rider' as user_type_name,
        'Pay-per-ride user without subscription' as user_type_description,
        false as has_subscription
    
    union all
    
    select
        'unknown' as user_type_id,
        'Unknown' as user_type_name,
        'User type not specified or missing' as user_type_description,
        null as has_subscription
)