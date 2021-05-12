# README

This repository contains a MapServer configuration and data, a minimal example to reproduce the the following issue:


For a particular boundingbox a series of paged WFS 2.0 GetFeature requests fails to retrieve all the features. The layer `beheer_leiding` is of geometry type `MULTILINESTRING`. The mapfile has the `wfs_maxfeatures` set to 1000, I assume this options should not break the WFS paging response.  The issue can be reproduced by starting the `docker-compose.yml`:

```
docker-compose up
```

And running the `page-wfs.sh` script:

```
./page-wfs.sh 80034.6,452005.1,81976.8,453965.8 gml3
current number of features: 1000
next_url: "http://localhost?SERVICE=WFS&SERVICE=WFS&version=2.0.0&service=wfs&request=Getfeature&bbox=80034.6,452005.1,81976.8,453965.8&outputformat=gml3&srsname=EPSG%3A28992&typename=gwsw%3Abeheer_leiding&STARTINDEX=1000"
current number of features: 1000
next_url: ""
total number of features: 2000
```

The bbox `80034.6,452005.1,81976.8,453965.8` retrieves 2000 features exactly. Not all the features are retrieved for the problematic bbox, because the paged request `http://localhost/?SERVICE=WFS&SERVICE=WFS&version=2.0.0&service=wfs&request=Getfeature&bbox=80034.6,452005.1,81976.8,453965.8&outputformat=gml3&srsname=EPSG%3A28992&typename=gwsw%3Abeheer_leiding&STARTINDEX=1000` does not contain a next link in the response body. But the next 1000 features are available: `http://localhost/?SERVICE=WFS&SERVICE=WFS&version=2.0.0&service=wfs&request=Getfeature&bbox=80034.6,452005.1,81976.8,453965.8&outputformat=gml3&srsname=EPSG%3A28992&typename=gwsw%3Abeheer_leiding&STARTINDEX=2000`. A slightly larger bbox retrieves all the features (feature count 3166):

```
./page-wfs.sh 80000.1,452000.1,82000.1,454000.1 gml3
```

The MS user email list seemed to suggest that some features could be skipped when the `rowid` column contains gaps,  because paging relies on the `rowid` column. So I ensured the `rowid` column (and therefore the fid) in the GeoPackage does not have any gaps. But this does not seem to affect the behaviour.


## Different datasource types

To see if I could reproduce the issue with different datasource types, I tried to reproduce the issue with GeoJSON and PostGIS as a datasource. Unfortunately this does not provide any insight on the cause of the issue. 

### GeoJSON

The behaviour changes when using a GeoJSON file as datasource. To do so change the datasource in the mapfile to `CONNECTION "/srv/data/data.json"` and run the paged WFS request with the problematic bbox:

```
 ./page-wfs.sh 80034.6,452005.1,81976.8,453965.8 gml3
current number of features: 1000
next_url: "http://localhost?SERVICE=WFS&SERVICE=WFS&version=2.0.0&service=wfs&request=Getfeature&bbox=80034.6,452005.1,81976.8,453965.8&outputformat=gml3&srsname=EPSG%3A28992&typename=gwsw%3Abeheer_leiding&STARTINDEX=1000"
current number of features: 1000
next_url: "http://localhost?SERVICE=WFS&SERVICE=WFS&SERVICE=WFS&version=2.0.0&service=wfs&request=Getfeature&bbox=80034.6,452005.1,81976.8,453965.8&outputformat=gml3&srsname=EPSG%3A28992&typename=gwsw%3Abeheer_leiding&STARTINDEX=2000"
current number of features: 1000
next_url: "http://localhost?SERVICE=WFS&SERVICE=WFS&SERVICE=WFS&SERVICE=WFS&version=2.0.0&service=wfs&request=Getfeature&bbox=80034.6,452005.1,81976.8,453965.8&outputformat=gml3&srsname=EPSG%3A28992&typename=gwsw%3Abeheer_leiding&STARTINDEX=3000"
current number of features: 40
next_url: ""
total number of features: 3040
```

The unproblematic bbox retrieves all the features as well.

### PostGIS

The behaviour does not change when using PostGIS as datasource. To do so comment the `ogr` datasource and uncomment the PostGIS datasource in the mapfile and restart the docker-compose. Then load the geopackage into PostGIS with `ogr2ogr`.

```shell
export PGPASSWORD=postgres;export PGCONN="PG:dbname='postgres' host='localhost' port='5432' user='postgres'"; ogr2ogr -f PostgreSQL $PGCONN assets/data.gpkg beheer_leiding
```

Running the paged WFS request with the problematic bbox does not return all the features:

```
 ./page-wfs.sh 80034.6,452005.1,81976.8,453965.8 gml3
current number of features: 1000
next_url: "http://localhost?SERVICE=WFS&SERVICE=WFS&version=2.0.0&service=wfs&request=Getfeature&bbox=80034.6,452005.1,81976.8,453965.8&outputformat=gml3&srsname=EPSG%3A28992&typename=gwsw%3Abeheer_leiding&STARTINDEX=1000"
current number of features: 1000
next_url: ""
total number of features: 2000
```

The unproblematic bbox retrieves all the features as expected.


## Analysing SQL queries 

The MapServer logs can be used to extract the SQL query used by MapServer. See the sql queries below for all the paged requests of the problematic bbox. For request without next link in the response body MapServer will log the following line: `msOGRFileNextShape: Returning MS_DONE (no more shapes)` . So this is the case for "Feature 1001-2000" and "Feature 3000-3040".

### Feature 1-1000

Url: http://localhost/?SERVICE=WFS&SERVICE=WFS&version=2.0.0&service=wfs&request=Getfeature&bbox=80034.6,452005.1,81976.8,453965.8&outputformat=gml3&srsname=EPSG%3A28992&typename=gwsw%3Abeheer_leiding

> sqlite3 data.gpkg <<< "SELECT "beheer_leiding"."uri" AS "uri", "beheer_leiding"."geometry" AS "geometry" FROM "beheer_leiding" JOIN "rtree_beheer_leiding_geometry" ms_spat_idx ON "beheer_leiding".ROWID = ms_spat_idx.id AND ms_spat_idx.minx <= 81976.8 AND ms_spat_idx.maxx >= 80034.6 AND ms_spat_idx.miny <= 453965.8 AND ms_spat_idx.maxy >= 452005.1  ORDER BY "beheer_leiding".ROWID LIMIT 1001" | wc -l
1001

### Feature 1001-2000

Url: http://localhost/?SERVICE=WFS&SERVICE=WFS&version=2.0.0&service=wfs&request=Getfeature&bbox=80034.6,452005.1,81976.8,453965.8&outputformat=gml3&srsname=EPSG%3A28992&typename=gwsw%3Abeheer_leiding&STARTINDEX=1000

```shell
> sqlite3 data.gpkg <<< "SELECT "beheer_leiding"."uri" AS "uri", "beheer_leiding"."geometry" AS "geometry" FROM "beheer_leiding" JOIN "rtree_beheer_leiding_geometry" ms_spat_idx ON "beheer_leiding".ROWID = ms_spat_idx.id AND ms_spat_idx.minx <= 81976.8 AND ms_spat_idx.maxx >= 80034.6 AND ms_spat_idx.miny <= 453965.8 AND ms_spat_idx.maxy >= 452005.1  ORDER BY "beheer_leiding".ROWID LIMIT 1001 OFFSET 1000" |wc -l
1001
```

### Feature 2001-3000

Url: http://localhost/?SERVICE=WFS&SERVICE=WFS&version=2.0.0&service=wfs&request=Getfeature&bbox=80034.6,452005.1,81976.8,453965.8&outputformat=gml3&srsname=EPSG%3A28992&typename=gwsw%3Abeheer_leiding&STARTINDEX=2000

```shell
> sqlite3 data.gpkg <<< "SELECT "beheer_leiding"."uri" AS "uri", "beheer_leiding"."geometry" AS "geometry" FROM "beheer_leiding" JOIN "rtree_beheer_leiding_geometry" ms_spat_idx ON "beheer_leiding".ROWID = ms_spat_idx.id AND ms_spat_idx.minx <= 81976.8 AND ms_spat_idx.maxx >= 80034.6 AND ms_spat_idx.miny <= 453965.8 AND ms_spat_idx.maxy >= 452005.1  ORDER BY "beheer_leiding".ROWID LIMIT 1001 OFFSET 2000" |wc -l
1001
```

### Feature 3000-3040

Url: http://localhost/?SERVICE=WFS&SERVICE=WFS&version=2.0.0&service=wfs&request=Getfeature&bbox=80034.6,452005.1,81976.8,453965.8&outputformat=gml3&srsname=EPSG%3A28992&typename=gwsw%3Abeheer_leiding&STARTINDEX=3000

```shell
> sqlite3 data.gpkg <<< "SELECT "beheer_leiding"."uri" AS "uri", "beheer_leiding"."geometry" AS "geometry" FROM "beheer_leiding" JOIN "rtree_beheer_leiding_geometry" ms_spat_idx ON "beheer_leiding".ROWID = ms_spat_idx.id AND ms_spat_idx.minx <= 81976.8 AND ms_spat_idx.maxx >= 80034.6 AND ms_spat_idx.miny <= 453965.8 AND ms_spat_idx.maxy >= 452005.1  ORDER BY "beheer_leiding".ROWID LIMIT 1001 OFFSET 3000" |wc -l
1001
```

## Changing geometrytype data

To verify if the behaviour still occurs with a point layer based first generate a point layer based on the `beheer_leiding` layer:

```
ogr2ogr -f GPKG data_points.gpkg data.gpkg -sql "select asgpb(Centroid(GeomFromGPB(geometry))) as geometry, geo_id, uri from  beheer_leiding" -nln beheer_leiding
```

Next update the mapfile and do not forget to change the layer geometry type: `TYPE POINT`. Then request the problemetic bbbox again:

```shell
./page-wfs.sh 80034.6,452005.1,81976.8,453965.8 gml3
current number of features: 1000
next_url: "http://localhost?SERVICE=WFS&SERVICE=WFS&version=2.0.0&service=wfs&request=Getfeature&bbox=80034.6%2C452005.1%2C81976.8%2C453965.8&outputformat=gml3&srsname=EPSG%3A28992&typename=gwsw%3Abeheer_leiding&STARTINDEX=1000"
current number of features: 1000
next_url: "http://localhost?SERVICE=WFS&SERVICE=WFS&SERVICE=WFS&version=2.0.0&service=wfs&request=Getfeature&bbox=80034.6%2C452005.1%2C81976.8%2C453965.8&outputformat=gml3&srsname=EPSG%3A28992&typename=gwsw%3Abeheer_leiding&STARTINDEX=2000"
current number of features: 953
next_url: ""
total number of features: 2953
```

This retrieves all the features within the bbox. So to me it seems there is a bug in the bbox filter in MapServer, maybe only occuring with `MULTILINESTRING` geometry types?



