-- Live traffic. Phones that are navigating send their speed on short stretches of road, with no id
-- of any kind. Only 5-minute averages per stretch and direction are kept, and only for an hour.

CREATE TABLE IF NOT EXISTS speeds (
  seg     TEXT NOT NULL,            -- "<row>:<col>:<dir>": a ~165 m square and one of 8 directions
  cell    INTEGER NOT NULL,         -- 0.1 degree square, for "near me" (same as reports.cell)
  minute  INTEGER NOT NULL,         -- start of the 5-minute bucket, ms since 1970
  lat     REAL NOT NULL,            -- centre of the small square
  lng     REAL NOT NULL,
  dir     INTEGER NOT NULL,         -- 0 = north, 1 = north-east ... 7 = north-west
  sum_kmh REAL NOT NULL,
  n       INTEGER NOT NULL,
  PRIMARY KEY (seg, minute)
);
CREATE INDEX IF NOT EXISTS speeds_cell_minute_idx ON speeds (cell, minute);
