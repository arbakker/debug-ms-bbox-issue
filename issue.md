# next link missing WFS 2.0 getfeature response for specific bbox

Hi, I am running into a problem with WFS 2.0 paged GetFeature request. The problem is that for a particular boundingbox a series of paged WFS 2.0 GetFeature requests fails to retrieve all the features. The geometry type of the layer is of `MULTILINESTRING`, the datasource is a GeoPackage file.

The problem is that the second paged response (http://localhost/?SERVICE=WFS&SERVICE=WFS&version=2.0.0&service=wfs&request=Getfeature&bbox=80034.6,452005.1,81976.8,453965.8&outputformat=gml3&srsname=EPSG%3A28992&typename=gwsw%3Abeheer_leiding&STARTINDEX=1000) is missing the next link. The missing next link does actually produces the expected features (http://localhost/?SERVICE=WFS&SERVICE=WFS&version=2.0.0&service=wfs&request=Getfeature&bbox=80034.6,452005.1,81976.8,453965.8&outputformat=gml3&srsname=EPSG%3A28992&typename=gwsw%3Abeheer_leiding&STARTINDEX=2000) **and** contains a next link itself. 

In MapServer logs when requesting the page with the missing next link, I see the following log output: `msOGRFileNextShape: Returning MS_DONE (no more shapes)`. This log output also shows when requesting the last page of results, of a paged WFS request. 

The interesting thing is that this behaviour does not occur when requesting a slightly bigger bbox: http://localhost/?SERVICE=WFS&SERVICE=WFS&version=2.0.0&service=wfs&request=Getfeature&bbox=80034.6%2C452005.1%2C81976.8%2C453965.8&outputformat=gml3&srsname=EPSG%3A28992&typename=gwsw%3Abeheer_leiding


The SQL query used by Mapserver when requesting the page (http://localhost/?SERVICE=WFS&SERVICE=WFS&version=2.0.0&service=wfs&request=Getfeature&bbox=80034.6,452005.1,81976.8,453965.8&outputformat=gml3&srsname=EPSG%3A28992&typename=gwsw%3Abeheer_leiding&STARTINDEX=1000) with the missing next link is:

```shell
> sqlite3 data.gpkg <<< "SELECT "beheer_leiding"."uri" AS "uri", "beheer_leiding"."geometry" AS "geometry" FROM "beheer_leiding" JOIN "rtree_beheer_leiding_geometry" ms_spat_idx ON "beheer_leiding".ROWID = ms_spat_idx.id AND ms_spat_idx.minx <= 81976.8 AND ms_spat_idx.maxx >= 80034.6 AND ms_spat_idx.miny <= 453965.8 AND ms_spat_idx.maxy >= 452005.1  ORDER BY "beheer_leiding".ROWID LIMIT 1001 OFFSET 1000" |wc -l
1001
```

This produces 1001 features as expected. So not sure why MapServer decides there are no more results left. The MS_DONE value is returned from [here](https://github.com/MapServer/MapServer/blob/dfdda8a18c69f22806c7d6e46bb2bf59f67ed941/mapogr.cpp#L2818) (7.6.2 release).


So I suspect it is a bug in MapServer, in determining if there are any features left in the result set. Did anyone see this behaviour before? 

I created a specific repo with the config files, data and a README to reproduce the issue. 





