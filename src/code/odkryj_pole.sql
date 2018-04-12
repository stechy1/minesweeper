CREATE OR REPLACE FUNCTION public.odkryj_pole(_id_pole integer)
  RETURNS void AS
$BODY$
DECLARE
	pole_r RECORD;
	tmp_x integer := 0;
	tmp_y integer := 0;
	sousedni_id integer := 0;
BEGIN

	SELECT * FROM pole INTO pole_r WHERE pole.id = _id_pole;
	
	-- Kontrola, ze odkryvane pole ma hodnotu 0
	-- Pokud hodnotu 0 nema, nemam co odkryvat
	if (pole_r.hodnota != 0) then
		return;
	end if;

	for tmp_x in pole_r.x - 1 .. pole_r.x + 1 loop
		for tmp_y in pole_r.y - 1 .. pole_r.y + 1 loop
			-- Pokud jsem na sve vlastni pozici --> skip
			continue WHEN (pole_r.x = tmp_x and pole_r.y = tmp_y);

			-- Pokud pole neexistuje, jsem za hranici hraciho pole --> skip
			continue WHEN (
				not exists(
					SELECT * 
					FROM pole 
					WHERE pole.x = tmp_x 
						AND pole.y = tmp_y 
						and pole.hodnota >= 0 
						and pole.id_oblasti = pole_r.id_oblasti
					)
				);

			-- Pokud jiz tah v sousedstvi existuje --> skip
			continue WHEN (
				EXISTS (
					select tah.cas 
					from pole 
					INNER JOIN tah 
					ON tah.id_pole = pole.id
					WHERE pole.x = tmp_x and pole.y = tmp_y and pole.id_oblasti = pole_r.id_oblasti
					)
				);

			-- Pokud jiz oznacena mina v sousedstvi existuje --> skip
			continue WHEN (
				EXISTS (
					select mina.cas 
					from pole 
					INNER JOIN mina 
					ON mina.id_pole = pole.id
					WHERE pole.x = tmp_x and pole.y = tmp_y and pole.id_oblasti = pole_r.id_oblasti
					)
				);

			-- Ziskam si ID sousedniho pole
			SELECT pole.id 
			FROM pole 
			INTO sousedni_id 
			WHERE pole.x = tmp_x 
				AND pole.y = tmp_y 
				and pole.hodnota != -1 
				and pole.id_oblasti = pole_r.id_oblasti;
			-- Tímto se zajisti neprima rekurze, takze budu vkladat sousedni tahy
			INSERT INTO tah VALUES (sousedni_id);
		end loop;
	end loop;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION public.odkryj_pole(integer)
  OWNER TO petr;