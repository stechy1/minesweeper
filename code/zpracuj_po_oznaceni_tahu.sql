CREATE OR REPLACE FUNCTION public.zpracuj_po_oznaceni_tahu()
  RETURNS trigger AS
$BODY$
DECLARE
	vyhrano boolean := false;
	oblast_id integer := 0;
BEGIN
	SELECT pole.id_oblasti into oblast_id from pole where pole.id = NEW.id_pole;
	
	-- Aktualizace zaznamu o prvni tahu ve hre, pokud se jedna o prvni tah
	UPDATE hra SET prvni_tah = NEW.id_pole WHERE hra.id_oblasti = oblast_id AND hra.prvni_tah IS NULL;
	
	PERFORM odkryj_pole(NEW.id_pole);
	
	-- Aktualizace zaznamu o poslednim tahu ve hre
	UPDATE hra SET posledni_tah = NEW.id_pole WHERE hra.id_oblasti = oblast_id;

	select vyhra(NEW.id_pole) INTO vyhrano;

	if vyhrano then
		PERFORM oznac_miny(oblast_id);
		UPDATE hra SET id_stav = 2 WHERE hra.id_oblasti = oblast_id;
		RAISE NOTICE 'Konec hry' USING
		hint = 'Gratuluji k uspesnemu procisteni herniho pole';
	end if;

	RETURN NEW;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;