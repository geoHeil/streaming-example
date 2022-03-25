/*

The purpose of this model is to create a flight_information staging model
with light transformations on top of the source.
*/

{{ config(
    materialized='view'
) }}


WITH source AS (

    SELECT * FROM {{ ref('rp_commercials_information') }}

),

renamed AS (

    SELECT

       brand as brand,
       duration as duration,
       rating as rating

    FROM source

)

SELECT * FROM renamed
