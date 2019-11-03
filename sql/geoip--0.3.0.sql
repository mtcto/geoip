/*
 * Author: Tomas Vondra
 *
 * Created at: Sat Mar 31 22:51:21 +0200 2012
 */

/* country locations */
CREATE TABLE geoip_country_locations (
    geoname_id             INT     PRIMARY KEY,
    locale_code            CHAR(2) NOT NULL,
    continent_code         CHAR(2),
    continent_name         TEXT,
    country_iso_code       CHAR(2),
    country_name           TEXT,
    is_in_european_union   BOOL
);

/* IPv4/IPv6 blocks for countries */
CREATE TABLE geoip_country_blocks (
    network                INET NOT NULL,
    geoname_id             INT  REFERENCES geoip_country_locations(geoname_id),
    registered_country_id  INT,
    represented_country_id INT,
    is_anonymous_proxy     BOOL NOT NULL,
    is_satellite_provider  BOOL NOT NULL
);

/* city locations */
CREATE TABLE geoip_city_locations (
    geoname_id             INT     PRIMARY KEY,
    locale_code            CHAR(2) NOT NULL,
    continent_code         CHAR(2),
    continent_name         TEXT,
    country_iso_code       CHAR(2),
    country_name           TEXT,
    subdivision_1_iso_code TEXT,
    subdivision_1_name     TEXT,
    subdivision_2_iso_code TEXT,
    subdivision_2_name     TEXT,
    city_name              TEXT,
    metro_code             TEXT,
    time_zone              TEXT,
    is_in_european_union   BOOL
);

/* IPv4/IPv6 blocks for cities */
CREATE TABLE geoip_city_blocks (
    network                INET NOT NULL,
    geoname_id             INT  REFERENCES geoip_city_locations(geoname_id),
    registered_country_id  INT,
    represented_country_id INT,
    is_anonymous_proxy     BOOL NOT NULL,
    is_satellite_provider  BOOL NOT NULL,
    postal_code            TEXT,
    latitude               DOUBLE PRECISION,
    longitude              DOUBLE PRECISION,
    accuracy_radius        DOUBLE PRECISION
);

/* */
CREATE TABLE geoip_asn_blocks (
    network                   INET NOT NULL,
    autonomous_system_number  INT,
    autonomous_system_organization TEXT
);

CREATE INDEX geoip_country_blocks_idx ON geoip_country_blocks USING gist (network inet_ops);
CREATE INDEX geoip_city_blocks_idx ON geoip_city_blocks USING gist (network inet_ops);
CREATE INDEX geoip_asn_blocks_idx ON geoip_asn_blocks USING gist (network inet_ops);

-- search country, returns just the country code (2 characters)
CREATE OR REPLACE FUNCTION geoip_country_code(p_ip INET) RETURNS CHAR(2) AS $$

    SELECT country_iso_code
      FROM @extschema@.geoip_country_blocks JOIN @extschema@.geoip_city_locations USING (geoname_id)
     WHERE $1 <<= network ORDER BY network DESC LIMIT 1;

$$ LANGUAGE sql;

-- search city, returns just the location ID (PK of the geoip_city_location)
CREATE OR REPLACE FUNCTION geoip_city_location(p_ip INET) RETURNS INT AS $$

    SELECT geoname_id
      FROM @extschema@.geoip_city_blocks JOIN @extschema@.geoip_city_locations USING (geoname_id)
     WHERE $1 <<= network ORDER BY network DESC LIMIT 1;

$$ LANGUAGE sql;

-- search city, returns all the city details (zipcode, GPS etc.)
CREATE OR REPLACE FUNCTION geoip_city(p_ip INET, OUT geoname_id INT, OUT country_iso_code CHAR(2), OUT city_name VARCHAR(100),
                                                 OUT postal_code VARCHAR(10), OUT metro_code TEXT,
                                                 OUT latitude DOUBLE PRECISION, OUT longitude DOUBLE PRECISION) AS $$

    SELECT l.geoname_id, country_iso_code, city_name, postal_code, metro_code, latitude, longitude
      FROM @extschema@.geoip_city_blocks b JOIN @extschema@.geoip_city_locations l USING (geoname_id)
     WHERE $1 <<= network ORDER BY network DESC LIMIT 1;

$$ LANGUAGE sql;

-- search country, returns all the details
CREATE OR REPLACE FUNCTION geoip_country(p_ip INET, OUT network INET, OUT country_iso_code CHAR(2), OUT country_name VARCHAR(100)) AS $$

    SELECT network, country_iso_code, country_name
      FROM @extschema@.geoip_country_blocks JOIN @extschema@.geoip_country_locations USING (geoname_id)
     WHERE $1 <<= network ORDER BY network DESC LIMIT 1;

$$ LANGUAGE sql;

-- search ASN, returns the IP range and ASN name
CREATE OR REPLACE FUNCTION geoip_asn(p_ip INET, OUT network INET, OUT asn_number INT, OUT asn_name TEXT) AS $$

    SELECT network, autonomous_system_number, autonomous_system_organization
      FROM @extschema@.geoip_asn_blocks WHERE $1 <<= network ORDER BY network DESC LIMIT 1;

$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION geoip_bigint_to_inet(p_ip BIGINT) RETURNS inet AS $$
    SELECT (($1 >> 24 & 255) || '.' || ($1 >> 16 & 255) || '.' || ($1 >> 8 & 255) || '.' || ($1 & 255))::inet
$$ LANGUAGE sql strict immutable;
