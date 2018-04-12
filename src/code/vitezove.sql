CREATE OR REPLACE VIEW public.vitezove WITH (security_barrier=false) AS 
 SELECT hra.id AS id_hry,
    oblast.id AS id_oblasti,
    ( SELECT (( SELECT tah.cas
                   FROM hra hra_1
                     JOIN tah ON tah.id_pole = hra_1.posledni_tah
                  WHERE hra_1.id_oblasti = oblast.id)) - (( SELECT tah.cas
                   FROM hra hra_1
                     JOIN tah ON tah.id_pole = hra_1.prvni_tah
                  WHERE hra_1.id_oblasti = oblast.id))) AS doba_hrani,
    oblast.radku,
    oblast.sloupcu,
    oblast.min,
    oblast.obtiznost
   FROM hra
     JOIN oblast ON oblast.id = hra.id_oblasti
  WHERE hra.id_stav = 2;