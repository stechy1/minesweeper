CREATE OR REPLACE VIEW public.chybne_miny AS 
 SELECT pole.x,
    pole.y,
    pole.id_oblasti
   FROM mina
     JOIN pole ON pole.id = mina.id_pole
     JOIN hra ON hra.id_oblasti = pole.id_oblasti AND hra.id_stav = 3
  WHERE pole.hodnota <> '-1'::integer;