CREATE OR REPLACE FUNCTION public.vyhra(_id_pole integer)
  RETURNS boolean AS
$BODY$
DECLARE
	oblast_r RECORD;
	fields integer := 0;
	oznacenych_tahu integer := 0;
BEGIN

	-- Ulozim si cely zaznam o oblasti
	 SELECT oblast.id, oblast.radku, oblast.sloupcu, oblast.min, oblast.obtiznost INTO oblast_r FROM pole INNER JOIN oblast ON pole.id_oblasti = oblast.id WHERE pole.id = _id_pole;
	-- Spocitam si poce vsech poli
	fields := oblast_r.radku * oblast_r.sloupcu;
	-- Odectu pocet min abych ziskal, kolik zaznamu ma byt v tabulce "tah" pro vyhru
	fields := fields - oblast_r.min;

	-- Ziskam pocet oznacenych tahu
	SELECT COUNT(tah.id_pole) INTO oznacenych_tahu FROM tah INNER JOIN pole ON pole.id=tah.id_pole WHERE pole.id_oblasti = oblast_r.id;

	-- Vyhra nastava v pripade, ze pocet tahu odpovida poctu prazdnych poli
	return fields = oznacenych_tahu;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;