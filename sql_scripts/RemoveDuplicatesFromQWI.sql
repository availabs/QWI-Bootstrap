SELECT ctid FROM qwi WHERE ctid NOT IN 
(SELECT max(ctid) FROM qwi GROUP BY qwi.*);
