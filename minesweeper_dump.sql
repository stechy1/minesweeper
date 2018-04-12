--
-- PostgreSQL database dump
--

-- Dumped from database version 9.5.12
-- Dumped by pg_dump version 9.5.12

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

DROP DATABASE petr;
--
-- Name: petr; Type: DATABASE; Schema: -; Owner: petr
--

CREATE DATABASE petr WITH TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'cs_CZ.UTF-8' LC_CTYPE = 'cs_CZ.UTF-8';


ALTER DATABASE petr OWNER TO petr;

\connect petr

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: je_dohrano(text, integer); Type: FUNCTION; Schema: public; Owner: petr
--

CREATE FUNCTION public.je_dohrano(_zdroj text, _id_pole integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$BEGIN
	if _zdroj = 'tah' then
		return exists (
			SELECT distinct hra.id
			FROM tah
			INNER JOIN pole ON pole.id = _id_pole 
			INNER JOIN oblast ON oblast.id = pole.id_oblasti
			INNER JOIN hra ON hra.id_oblasti = oblast.id
			WHERE hra.id_stav != 1
		);
	elsif _zdroj = 'mina' then
		return exists (
			SELECT distinct hra.id
			FROM mina
			INNER JOIN pole ON pole.id = _id_pole
			INNER JOIN oblast ON oblast.id = pole.id_oblasti
			INNER JOIN hra ON hra.id_oblasti = oblast.id
			WHERE hra.id_stav != 1
		);
	end if;

	RAISE EXCEPTION 'Zadali jste nespravny parametr';
END;
$$;


ALTER FUNCTION public.je_dohrano(_zdroj text, _id_pole integer) OWNER TO petr;

--
-- Name: mnoho_min(integer); Type: FUNCTION; Schema: public; Owner: petr
--

CREATE FUNCTION public.mnoho_min(_id_pole integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$DECLARE
	oblast_id integer := 0;
	celkem_min integer := 0;
	oznacenych_min integer := 0;
BEGIN
	
	SELECT oblast.id, oblast.min INTO oblast_id, celkem_min FROM pole INNER JOIN oblast ON pole.id_oblasti = oblast.id WHERE pole.id = _id_pole;

	SELECT COUNT(mina.id_pole) INTO oznacenych_min FROM mina INNER JOIN pole ON pole.id=mina.id_pole WHERE pole.id_oblasti = oblast_id;

	return ((oznacenych_min + 1) > celkem_min);

	
END
$$;


ALTER FUNCTION public.mnoho_min(_id_pole integer) OWNER TO petr;

--
-- Name: odkryj_pole(integer); Type: FUNCTION; Schema: public; Owner: petr
--

CREATE FUNCTION public.odkryj_pole(_id_pole integer) RETURNS void
    LANGUAGE plpgsql
    AS $$DECLARE
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
END;$$;


ALTER FUNCTION public.odkryj_pole(_id_pole integer) OWNER TO petr;

--
-- Name: odkryta_mina(integer); Type: FUNCTION; Schema: public; Owner: petr
--

CREATE FUNCTION public.odkryta_mina(_id_pole integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
BEGIN
	return exists (
		select pole.id_oblasti 
		from pole 
		where pole.id = _id_pole and pole.hodnota = -1);
END;
$$;


ALTER FUNCTION public.odkryta_mina(_id_pole integer) OWNER TO petr;

--
-- Name: oznac_miny(integer); Type: FUNCTION; Schema: public; Owner: petr
--

CREATE FUNCTION public.oznac_miny(_id_oblasti integer) RETURNS void
    LANGUAGE plpgsql
    AS $$

BEGIN
	INSERT INTO mina (id_pole) (
		SELECT pole.id FROM pole WHERE pole.id_oblasti = _id_oblasti AND pole.hodnota = -1
		EXCEPT
		SELECT mina.id_pole FROM mina INNER JOIN pole ON pole.id=mina.id_pole WHERE pole.id_oblasti = _id_oblasti
	);
END

$$;


ALTER FUNCTION public.oznac_miny(_id_oblasti integer) OWNER TO petr;

--
-- Name: pokus_kopiruj_interval(integer, integer); Type: FUNCTION; Schema: public; Owner: petr
--

CREATE FUNCTION public.pokus_kopiruj_interval(dolni_mez integer, horni_mez integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
	p RECORD;
	curr_date TIME;
	u character(50);
	rozmezi CURSOR (dolni integer, horni integer) FOR
		SELECT * FROM "POKUS" WHERE "POKUS".kod > dolni AND "POKUS".kod < horni;
BEGIN
	FOR p IN rozmezi(dolni_mez, horni_mez) LOOP
		SELECT CURRENT_TIME INTO curr_date;
		SELECT user INTO u;
		INSERT INTO "POKUS_INTERVAL" (kod, hodnota, datum_kopirovani, uzivatel) VALUES (p.kod, p.hodnota, curr_date, u);
	END LOOP;
END
$$;


ALTER FUNCTION public.pokus_kopiruj_interval(dolni_mez integer, horni_mez integer) OWNER TO petr;

--
-- Name: pokus_vloz(character); Type: FUNCTION; Schema: public; Owner: petr
--

CREATE FUNCTION public.pokus_vloz(h character) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
	stary integer;
	novy integer;
BEGIN
	SELECT kod INTO stary FROM "POKUS" order by kod desc limit 1;
	novy := stary + 1;
	INSERT INTO "POKUS" (kod, hodnota) VALUES (novy, h);
exception when others then
	INSERT INTO "POKUS" (kod, hodnota) VALUES (1, h);
END
$$;


ALTER FUNCTION public.pokus_vloz(h character) OWNER TO petr;

--
-- Name: radek_oblasti(integer, integer); Type: FUNCTION; Schema: public; Owner: petr
--

CREATE FUNCTION public.radek_oblasti(oblast_id integer, cislo_radku integer) RETURNS text
    LANGUAGE plpgsql
    AS $$DECLARE
	radek_cursor CURSOR (oblast_id integer, radek integer) for
		select pole.id, pole.hodnota, pole.x 
		from pole 
		where pole.id_oblasti = oblast_id and pole.y = radek 
		order by pole.x asc;
	radek RECORD;
	vystup text := '';
	entry character(1) := '?';
BEGIN
	OPEN radek_cursor(oblast_id, cislo_radku);

	LOOP
      FETCH radek_cursor INTO radek;
      EXIT WHEN NOT FOUND;
 
      	if exists (select * from mina where mina.id_pole = radek.id) then
      		-- mina je oznacena
      		vystup := vystup || '+';
      	elsif exists (select * from tah where tah.id_pole = radek.id) then
      		-- prazdne pole je oznaceno
		if radek.hodnota = -1 then
			vystup := vystup || '+';
		else
			vystup := vystup || radek.hodnota::text;
		end if;
      	else
      		vystup := vystup || entry;
      	end if;

      	entry := '?';

   	END LOOP;

	CLOSE radek_cursor;

	return vystup;
END$$;


ALTER FUNCTION public.radek_oblasti(oblast_id integer, cislo_radku integer) OWNER TO petr;

--
-- Name: spatny_parametr(); Type: FUNCTION; Schema: public; Owner: petr
--

CREATE FUNCTION public.spatny_parametr() RETURNS trigger
    LANGUAGE plpgsql
    AS $$DECLARE
	tmp_hodnota omezeni.hodnota%TYPE;
	existujici_obtiznost RECORD;
BEGIN
	if NEW.obtiznost = 'zacatecnik' or NEW.obtiznost = 'pokrocily' or NEW.obtiznost = 'expert' then
		select obtiznost.radku, obtiznost.sloupcu, obtiznost.min 
		into existujici_obtiznost 
		from obtiznost 
		where obtiznost.nazev = NEW.obtiznost;
		
		NEW.radku := existujici_obtiznost.radku;
		NEW.sloupcu := existujici_obtiznost.sloupcu;
		NEW.min := existujici_obtiznost.min;
		
		return NEW;
	end if;

	select omezeni.hodnota into tmp_hodnota from omezeni where popisek = 'minimalni velikost';
	if NEW.radku < tmp_hodnota or NEW.sloupcu < tmp_hodnota then
		RAISE EXCEPTION 'Oblast je prilis mala' USING 
		hint = 'Pocet radku nebo sloupcu je prilis maly';
	end if;

	select omezeni.hodnota into tmp_hodnota from omezeni where popisek = 'maximalni velikost';
	if NEW.radku > tmp_hodnota or NEW.sloupcu > tmp_hodnota then
		RAISE EXCEPTION 'Oblast je prilis velka' USING 
		hint = 'Pocet radku nebo sloupcu je prilis veliky';
	end if;
	
	select omezeni.hodnota into tmp_hodnota from omezeni where popisek = 'maximum min';
	if NEW.min > tmp_hodnota or NEW.min > NEW.sloupcu * NEW.radku then
		RAISE EXCEPTION 'Tolik min se do oblasti nevejde!' USING 
		hint = 'Snizte pocet min';
	end if;
	
	select omezeni.hodnota into tmp_hodnota from omezeni where popisek = 'minimum min';
	if NEW.min < tmp_hodnota then
		RAISE EXCEPTION 'Prilis malo min' USING 
		hint = 'Zvyste pocet min';
	end if;
	
	RETURN NEW;
END;$$;


ALTER FUNCTION public.spatny_parametr() OWNER TO petr;

--
-- Name: spocitej_oblast(integer, integer, integer); Type: FUNCTION; Schema: public; Owner: petr
--

CREATE FUNCTION public.spocitej_oblast(_oblast_id integer, _sloupcu integer, _radku integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
	tmp_x integer := 1;
	tmp_y integer := 1;
	tmp_8_okoli integer := 0;
BEGIN
	for tmp_x in 1 .. _sloupcu loop
		for tmp_y in 1 .. _radku loop
			-- vyfiltruji pole, na kterem je mina - na tomto poli prazdnou oblast nepocitam
			continue when exists (select id from pole where pole.id_oblasti = _oblast_id and pole.hodnota = -1 and pole.x = tmp_x and pole.y = tmp_y);
			
			-- tento select mi vybere vsechna zaminovana policka v 8-okoli
			select count(*) 
			into tmp_8_okoli
			from pole 
			where pole.id_oblasti = _oblast_id 
				and (pole.x between tmp_x - 1 and tmp_x + 1) 
				and (pole.y between tmp_y - 1 and tmp_y + 1) 
				and pole.hodnota = -1;
			insert into pole (x, y, hodnota, id_oblasti) values (tmp_x, tmp_y, tmp_8_okoli, _oblast_id);
		end loop; -- tmp_y
	end loop; -- tmp_x
END;
$$;


ALTER FUNCTION public.spocitej_oblast(_oblast_id integer, _sloupcu integer, _radku integer) OWNER TO petr;

--
-- Name: vyhra(integer); Type: FUNCTION; Schema: public; Owner: petr
--

CREATE FUNCTION public.vyhra(_id_pole integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$DECLARE
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
$$;


ALTER FUNCTION public.vyhra(_id_pole integer) OWNER TO petr;

--
-- Name: zaminuj_oblast(); Type: FUNCTION; Schema: public; Owner: petr
--

CREATE FUNCTION public.zaminuj_oblast() RETURNS trigger
    LANGUAGE plpgsql
    AS $$-- NEW = oblast
-- NEW.id NEW.radku NEW.sloupcu NEW.min NEW.obtiznost
DECLARE
	counter integer := 0;
	rand_x integer;
	rand_y integer;
BEGIN
	while counter < NEW.min loop
		rand_x := floor(random() * NEW.sloupcu) + 1;
		rand_y := floor(random() * NEW.radku) + 1;
		if not exists (select id from pole where pole.id_oblasti = NEW.id and pole.x = rand_x and pole.y = rand_y) then
			insert into pole (x, y, hodnota, id_oblasti) values (rand_x, rand_y, -1, NEW.id);
			counter := counter + 1;
		end if; -- pole je prazdne
	end loop; -- counter
	
	PERFORM spocitej_oblast(NEW.id, NEW.sloupcu, NEW.radku);

	insert into hra (prvni_tah, posledni_tah, id_stav, id_oblasti)
		values (NULL, NULL, 1, NEW.id);
	
	RETURN NEW;
END

$$;


ALTER FUNCTION public.zaminuj_oblast() OWNER TO petr;

--
-- Name: zpracuj_po_oznaceni_miny(); Type: FUNCTION; Schema: public; Owner: petr
--

CREATE FUNCTION public.zpracuj_po_oznaceni_miny() RETURNS trigger
    LANGUAGE plpgsql
    AS $$BEGIN

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.zpracuj_po_oznaceni_miny() OWNER TO petr;

--
-- Name: zpracuj_po_oznaceni_tahu(); Type: FUNCTION; Schema: public; Owner: petr
--

CREATE FUNCTION public.zpracuj_po_oznaceni_tahu() RETURNS trigger
    LANGUAGE plpgsql
    AS $$DECLARE
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
$$;


ALTER FUNCTION public.zpracuj_po_oznaceni_tahu() OWNER TO petr;

--
-- Name: zpracuj_pred_oznacenim_miny(); Type: FUNCTION; Schema: public; Owner: petr
--

CREATE FUNCTION public.zpracuj_pred_oznacenim_miny() RETURNS trigger
    LANGUAGE plpgsql
    AS $$DECLARE
	dohrano boolean := false;
	je_mnoho_min boolean := false;
BEGIN
	-- Pokud hra byla ukoncena, vyhodim vyjimku
	SELECT je_dohrano('mina', NEW.id_pole) INTO dohrano;
	if (dohrano) then
		RAISE EXCEPTION 'Hra jiz byla ukoncena' USING 
		hint = 'Vytvorte si novou hru pro dalsi hrani.';
		return NULL;
	end if;

	-- Pokud jiz mam minu oznacenou, tak oznaceni zrusim
	if EXISTS (SELECT * FROM mina WHERE mina.id_pole = NEW.id_pole) then
		DELETE FROM mina WHERE mina.id_pole = NEW.id_pole;
		return NULL;
	end if;
	
	-- Pokud je toto pole oznaceno jako odehrany tah, nic se nestane
	if EXISTS (SELECT * FROM tah WHERE tah.id_pole = NEW.id_pole) then
		RAISE EXCEPTION 'Neplatna mina' USING
		hint = 'Minu nelze oznacit na jiz odehranem poli';
		return NULL;
	end if;
	
	SELECT mnoho_min(NEW.id_pole) INTO je_mnoho_min;
	if (je_mnoho_min) then
		RAISE WARNING 'Nelze oznacit vice zaminovanych poli, nez kolik je min v oblasti' USING
		hint = 'Vypada to, ze jste oznacili miny i tam, kde nejsou.';
		
		return NULL;
	end if;
	
	return NEW;
END;
$$;


ALTER FUNCTION public.zpracuj_pred_oznacenim_miny() OWNER TO petr;

--
-- Name: zpracuj_pred_oznacenim_tahu(); Type: FUNCTION; Schema: public; Owner: petr
--

CREATE FUNCTION public.zpracuj_pred_oznacenim_tahu() RETURNS trigger
    LANGUAGE plpgsql
    AS $$DECLARE
	dohrano boolean := false;
	nasel_minu boolean := false;
	oblast_id integer := 0;
BEGIN
	-- Pokud hra byla ukoncena, vyhodim vyjimku
	SELECT je_dohrano('tah', NEW.id_pole) INTO dohrano;
	if (dohrano) then
		RAISE EXCEPTION 'Hra jiz byla ukoncena' USING
		hint = 'Vytvorte si novou hru pro dalsi hrani.';
		return NULL;
	end if;

	-- Pokud je toto pole oznaceno jako mina
	if EXISTS (SELECT * FROM mina WHERE mina.id_pole = NEW.id_pole) then
		RAISE EXCEPTION 'Neplatny tah' USING
		hint = 'Tah nelze zahrat na oznacene mine';
		return NULL;
	end if;

	SELECT odkryta_mina(NEW.id_pole) into nasel_minu;
	if (nasel_minu) then
	
		SELECT pole.id_oblasti into oblast_id from pole where pole.id = NEW.id_pole;
		UPDATE hra SET id_stav = 3 WHERE hra.id_oblasti = oblast_id;

		RAISE INFO 'Konec hry' USING
		hint = 'Odkryl jste neoznacenou minu. Konec hry';
	end if;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.zpracuj_pred_oznacenim_tahu() OWNER TO petr;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: hra; Type: TABLE; Schema: public; Owner: petr
--

CREATE TABLE public.hra (
    id integer NOT NULL,
    prvni_tah integer,
    posledni_tah integer,
    id_stav integer,
    id_oblasti integer
);


ALTER TABLE public.hra OWNER TO petr;

--
-- Name: mina; Type: TABLE; Schema: public; Owner: petr
--

CREATE TABLE public.mina (
    id_pole integer NOT NULL,
    cas timestamp without time zone DEFAULT now()
);


ALTER TABLE public.mina OWNER TO petr;

--
-- Name: pole; Type: TABLE; Schema: public; Owner: petr
--

CREATE TABLE public.pole (
    id integer NOT NULL,
    x integer,
    y integer,
    hodnota integer,
    id_oblasti integer
);


ALTER TABLE public.pole OWNER TO petr;

--
-- Name: chybne_miny; Type: VIEW; Schema: public; Owner: petr
--

CREATE VIEW public.chybne_miny AS
 SELECT pole.x,
    pole.y,
    pole.id_oblasti
   FROM ((public.mina
     JOIN public.pole ON ((pole.id = mina.id_pole)))
     JOIN public.hra ON (((hra.id_oblasti = pole.id_oblasti) AND (hra.id_stav = 3))))
  WHERE (pole.hodnota <> '-1'::integer);


ALTER TABLE public.chybne_miny OWNER TO petr;

--
-- Name: hra_id_seq; Type: SEQUENCE; Schema: public; Owner: petr
--

CREATE SEQUENCE public.hra_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.hra_id_seq OWNER TO petr;

--
-- Name: hra_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: petr
--

ALTER SEQUENCE public.hra_id_seq OWNED BY public.hra.id;


--
-- Name: oblast; Type: TABLE; Schema: public; Owner: petr
--

CREATE TABLE public.oblast (
    id integer NOT NULL,
    radku integer,
    sloupcu integer,
    min integer,
    obtiznost text
);


ALTER TABLE public.oblast OWNER TO petr;

--
-- Name: oblast_id_seq; Type: SEQUENCE; Schema: public; Owner: petr
--

CREATE SEQUENCE public.oblast_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.oblast_id_seq OWNER TO petr;

--
-- Name: oblast_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: petr
--

ALTER SEQUENCE public.oblast_id_seq OWNED BY public.oblast.id;


--
-- Name: oblast_tisk; Type: VIEW; Schema: public; Owner: petr
--

CREATE VIEW public.oblast_tisk WITH (security_barrier='false') AS
 SELECT DISTINCT pole.id_oblasti,
    pole.y,
    public.radek_oblasti(pole.id_oblasti, pole.y) AS radek_oblasti,
    hra.id_stav
   FROM (public.pole
     JOIN public.hra ON ((hra.id_oblasti = pole.id_oblasti)))
  ORDER BY pole.y;


ALTER TABLE public.oblast_tisk OWNER TO petr;

--
-- Name: obtiznost; Type: TABLE; Schema: public; Owner: petr
--

CREATE TABLE public.obtiznost (
    id integer NOT NULL,
    nazev character varying(80) NOT NULL,
    radku integer NOT NULL,
    sloupcu integer NOT NULL,
    min integer NOT NULL
);


ALTER TABLE public.obtiznost OWNER TO petr;

--
-- Name: obtiznost_id_seq; Type: SEQUENCE; Schema: public; Owner: petr
--

CREATE SEQUENCE public.obtiznost_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.obtiznost_id_seq OWNER TO petr;

--
-- Name: obtiznost_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: petr
--

ALTER SEQUENCE public.obtiznost_id_seq OWNED BY public.obtiznost.id;


--
-- Name: omezeni; Type: TABLE; Schema: public; Owner: petr
--

CREATE TABLE public.omezeni (
    popisek character(50) NOT NULL,
    hodnota integer
);


ALTER TABLE public.omezeni OWNER TO petr;

--
-- Name: pole_id_seq; Type: SEQUENCE; Schema: public; Owner: petr
--

CREATE SEQUENCE public.pole_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pole_id_seq OWNER TO petr;

--
-- Name: pole_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: petr
--

ALTER SEQUENCE public.pole_id_seq OWNED BY public.pole.id;


--
-- Name: tah; Type: TABLE; Schema: public; Owner: petr
--

CREATE TABLE public.tah (
    id_pole integer NOT NULL,
    cas timestamp without time zone DEFAULT now()
);


ALTER TABLE public.tah OWNER TO petr;

--
-- Name: porazeni; Type: VIEW; Schema: public; Owner: petr
--

CREATE VIEW public.porazeni AS
 SELECT hra.id AS id_hry,
    oblast.id AS id_oblasti,
    ( SELECT (( SELECT tah.cas
                   FROM (public.hra hra_1
                     JOIN public.tah ON ((tah.id_pole = hra_1.posledni_tah)))
                  WHERE (hra_1.id_oblasti = oblast.id)) - ( SELECT tah.cas
                   FROM (public.hra hra_1
                     JOIN public.tah ON ((tah.id_pole = hra_1.prvni_tah)))
                  WHERE (hra_1.id_oblasti = oblast.id)))) AS doba_hrani,
    ( SELECT count(mina.id_pole) AS count
           FROM (public.mina
             JOIN public.pole ON (((pole.id = mina.id_pole) AND (pole.hodnota = '-1'::integer))))
          WHERE (pole.id_oblasti = oblast.id)) AS spravne_odhaleno,
    oblast.radku,
    oblast.sloupcu,
    oblast.min,
    oblast.obtiznost
   FROM (public.hra
     JOIN public.oblast ON ((oblast.id = hra.id_oblasti)))
  WHERE (hra.id_stav = 3);


ALTER TABLE public.porazeni OWNER TO petr;

--
-- Name: rozehrane_hry; Type: VIEW; Schema: public; Owner: petr
--

CREATE VIEW public.rozehrane_hry WITH (security_barrier='false') AS
 SELECT DISTINCT oblast.id,
    oblast.radku,
    oblast.sloupcu,
    oblast.obtiznost
   FROM (public.hra
     JOIN public.oblast ON ((oblast.id = hra.id_oblasti)))
  WHERE (hra.id_stav = 1);


ALTER TABLE public.rozehrane_hry OWNER TO petr;

--
-- Name: stav; Type: TABLE; Schema: public; Owner: petr
--

CREATE TABLE public.stav (
    id integer NOT NULL,
    popis character varying(80) NOT NULL
);


ALTER TABLE public.stav OWNER TO petr;

--
-- Name: stav_id_seq; Type: SEQUENCE; Schema: public; Owner: petr
--

CREATE SEQUENCE public.stav_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.stav_id_seq OWNER TO petr;

--
-- Name: stav_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: petr
--

ALTER SEQUENCE public.stav_id_seq OWNED BY public.stav.id;


--
-- Name: vitezove; Type: VIEW; Schema: public; Owner: petr
--

CREATE VIEW public.vitezove WITH (security_barrier='false') AS
 SELECT hra.id AS id_hry,
    oblast.id AS id_oblasti,
    ( SELECT (( SELECT tah.cas
                   FROM (public.hra hra_1
                     JOIN public.tah ON ((tah.id_pole = hra_1.posledni_tah)))
                  WHERE (hra_1.id_oblasti = oblast.id)) - ( SELECT tah.cas
                   FROM (public.hra hra_1
                     JOIN public.tah ON ((tah.id_pole = hra_1.prvni_tah)))
                  WHERE (hra_1.id_oblasti = oblast.id)))) AS doba_hrani,
    oblast.radku,
    oblast.sloupcu,
    oblast.min,
    oblast.obtiznost
   FROM (public.hra
     JOIN public.oblast ON ((oblast.id = hra.id_oblasti)))
  WHERE (hra.id_stav = 2);


ALTER TABLE public.vitezove OWNER TO petr;

--
-- Name: id; Type: DEFAULT; Schema: public; Owner: petr
--

ALTER TABLE ONLY public.hra ALTER COLUMN id SET DEFAULT nextval('public.hra_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: petr
--

ALTER TABLE ONLY public.oblast ALTER COLUMN id SET DEFAULT nextval('public.oblast_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: petr
--

ALTER TABLE ONLY public.obtiznost ALTER COLUMN id SET DEFAULT nextval('public.obtiznost_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: petr
--

ALTER TABLE ONLY public.pole ALTER COLUMN id SET DEFAULT nextval('public.pole_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: petr
--

ALTER TABLE ONLY public.stav ALTER COLUMN id SET DEFAULT nextval('public.stav_id_seq'::regclass);


--
-- Data for Name: hra; Type: TABLE DATA; Schema: public; Owner: petr
--

COPY public.hra (id, prvni_tah, posledni_tah, id_stav, id_oblasti) FROM stdin;
\.


--
-- Name: hra_id_seq; Type: SEQUENCE SET; Schema: public; Owner: petr
--

SELECT pg_catalog.setval('public.hra_id_seq', 1, true);


--
-- Data for Name: mina; Type: TABLE DATA; Schema: public; Owner: petr
--

COPY public.mina (id_pole, cas) FROM stdin;
\.


--
-- Data for Name: oblast; Type: TABLE DATA; Schema: public; Owner: petr
--

COPY public.oblast (id, radku, sloupcu, min, obtiznost) FROM stdin;
\.


--
-- Name: oblast_id_seq; Type: SEQUENCE SET; Schema: public; Owner: petr
--

SELECT pg_catalog.setval('public.oblast_id_seq', 1, true);


--
-- Data for Name: obtiznost; Type: TABLE DATA; Schema: public; Owner: petr
--

COPY public.obtiznost (id, nazev, radku, sloupcu, min) FROM stdin;
1	zacatecnik	9	9	10
2	pokrocily	16	16	40
3	expert	16	30	99
\.


--
-- Name: obtiznost_id_seq; Type: SEQUENCE SET; Schema: public; Owner: petr
--

SELECT pg_catalog.setval('public.obtiznost_id_seq', 3, true);


--
-- Data for Name: omezeni; Type: TABLE DATA; Schema: public; Owner: petr
--

COPY public.omezeni (popisek, hodnota) FROM stdin;
minimalni velikost                                	9
maximalni velikost                                	100
minimum min                                       	1
\.


--
-- Data for Name: pole; Type: TABLE DATA; Schema: public; Owner: petr
--

COPY public.pole (id, x, y, hodnota, id_oblasti) FROM stdin;
\.


--
-- Name: pole_id_seq; Type: SEQUENCE SET; Schema: public; Owner: petr
--

SELECT pg_catalog.setval('public.pole_id_seq', 1, true);


--
-- Data for Name: stav; Type: TABLE DATA; Schema: public; Owner: petr
--

COPY public.stav (id, popis) FROM stdin;
1	rozehrana
2	uspesne ukoncena
3	neuspesne ukoncena
\.


--
-- Name: stav_id_seq; Type: SEQUENCE SET; Schema: public; Owner: petr
--

SELECT pg_catalog.setval('public.stav_id_seq', 3, true);


--
-- Data for Name: tah; Type: TABLE DATA; Schema: public; Owner: petr
--

COPY public.tah (id_pole, cas) FROM stdin;
\.


--
-- Name: hra_pkey; Type: CONSTRAINT; Schema: public; Owner: petr
--

ALTER TABLE ONLY public.hra
    ADD CONSTRAINT hra_pkey PRIMARY KEY (id);


--
-- Name: mina_pkey; Type: CONSTRAINT; Schema: public; Owner: petr
--

ALTER TABLE ONLY public.mina
    ADD CONSTRAINT mina_pkey PRIMARY KEY (id_pole);


--
-- Name: oblast_pkey; Type: CONSTRAINT; Schema: public; Owner: petr
--

ALTER TABLE ONLY public.oblast
    ADD CONSTRAINT oblast_pkey PRIMARY KEY (id);


--
-- Name: obtiznost_pkey; Type: CONSTRAINT; Schema: public; Owner: petr
--

ALTER TABLE ONLY public.obtiznost
    ADD CONSTRAINT obtiznost_pkey PRIMARY KEY (id);


--
-- Name: omezeni_pkey; Type: CONSTRAINT; Schema: public; Owner: petr
--

ALTER TABLE ONLY public.omezeni
    ADD CONSTRAINT omezeni_pkey PRIMARY KEY (popisek);


--
-- Name: pole_pkey; Type: CONSTRAINT; Schema: public; Owner: petr
--

ALTER TABLE ONLY public.pole
    ADD CONSTRAINT pole_pkey PRIMARY KEY (id);


--
-- Name: pole_x_y_id_oblasti_key; Type: CONSTRAINT; Schema: public; Owner: petr
--

ALTER TABLE ONLY public.pole
    ADD CONSTRAINT pole_x_y_id_oblasti_key UNIQUE (x, y, id_oblasti);


--
-- Name: stav_pkey; Type: CONSTRAINT; Schema: public; Owner: petr
--

ALTER TABLE ONLY public.stav
    ADD CONSTRAINT stav_pkey PRIMARY KEY (id);


--
-- Name: tah_id_pole_pkey; Type: CONSTRAINT; Schema: public; Owner: petr
--

ALTER TABLE ONLY public.tah
    ADD CONSTRAINT tah_id_pole_pkey PRIMARY KEY (id_pole);


--
-- Name: fki_hra_id_oblasti_fkey; Type: INDEX; Schema: public; Owner: petr
--

CREATE INDEX fki_hra_id_oblasti_fkey ON public.hra USING btree (id_oblasti);


--
-- Name: fki_hra_posledni_tah_fkey; Type: INDEX; Schema: public; Owner: petr
--

CREATE INDEX fki_hra_posledni_tah_fkey ON public.hra USING btree (posledni_tah);


--
-- Name: fki_pole_id_oblasti_fkey; Type: INDEX; Schema: public; Owner: petr
--

CREATE INDEX fki_pole_id_oblasti_fkey ON public.pole USING btree (id_oblasti);


--
-- Name: osetreni_parametru; Type: TRIGGER; Schema: public; Owner: petr
--

CREATE TRIGGER osetreni_parametru BEFORE INSERT ON public.obtiznost FOR EACH ROW EXECUTE PROCEDURE public.spatny_parametr();


--
-- Name: spust_kontrolu_min; Type: TRIGGER; Schema: public; Owner: petr
--

CREATE TRIGGER spust_kontrolu_min BEFORE INSERT ON public.mina FOR EACH ROW EXECUTE PROCEDURE public.zpracuj_pred_oznacenim_miny();


--
-- Name: spust_kontrolu_parametru; Type: TRIGGER; Schema: public; Owner: petr
--

CREATE TRIGGER spust_kontrolu_parametru BEFORE INSERT ON public.oblast FOR EACH ROW EXECUTE PROCEDURE public.spatny_parametr();


--
-- Name: spust_kontrolu_tahu; Type: TRIGGER; Schema: public; Owner: petr
--

CREATE TRIGGER spust_kontrolu_tahu BEFORE INSERT ON public.tah FOR EACH ROW EXECUTE PROCEDURE public.zpracuj_pred_oznacenim_tahu();


--
-- Name: spust_po_oznaceni_tahu; Type: TRIGGER; Schema: public; Owner: petr
--

CREATE TRIGGER spust_po_oznaceni_tahu AFTER INSERT ON public.tah FOR EACH ROW EXECUTE PROCEDURE public.zpracuj_po_oznaceni_tahu();


--
-- Name: spust_zaminovani_oblasti; Type: TRIGGER; Schema: public; Owner: petr
--

CREATE TRIGGER spust_zaminovani_oblasti AFTER INSERT ON public.oblast FOR EACH ROW EXECUTE PROCEDURE public.zaminuj_oblast();


--
-- Name: testuj_parametry; Type: TRIGGER; Schema: public; Owner: petr
--

CREATE TRIGGER testuj_parametry BEFORE INSERT ON public.obtiznost FOR EACH ROW EXECUTE PROCEDURE public.spatny_parametr();


--
-- Name: hra_id_oblasti_fkey; Type: FK CONSTRAINT; Schema: public; Owner: petr
--

ALTER TABLE ONLY public.hra
    ADD CONSTRAINT hra_id_oblasti_fkey FOREIGN KEY (id_oblasti) REFERENCES public.oblast(id);


--
-- Name: hra_id_stav_fkey; Type: FK CONSTRAINT; Schema: public; Owner: petr
--

ALTER TABLE ONLY public.hra
    ADD CONSTRAINT hra_id_stav_fkey FOREIGN KEY (id_stav) REFERENCES public.stav(id);


--
-- Name: hra_posledni_tah_fkey; Type: FK CONSTRAINT; Schema: public; Owner: petr
--

ALTER TABLE ONLY public.hra
    ADD CONSTRAINT hra_posledni_tah_fkey FOREIGN KEY (posledni_tah) REFERENCES public.tah(id_pole);


--
-- Name: hra_prvni_tah_fkey; Type: FK CONSTRAINT; Schema: public; Owner: petr
--

ALTER TABLE ONLY public.hra
    ADD CONSTRAINT hra_prvni_tah_fkey FOREIGN KEY (prvni_tah) REFERENCES public.tah(id_pole);


--
-- Name: mina_id_pole_fkey; Type: FK CONSTRAINT; Schema: public; Owner: petr
--

ALTER TABLE ONLY public.mina
    ADD CONSTRAINT mina_id_pole_fkey FOREIGN KEY (id_pole) REFERENCES public.pole(id);


--
-- Name: pole_id_oblasti_fkey; Type: FK CONSTRAINT; Schema: public; Owner: petr
--

ALTER TABLE ONLY public.pole
    ADD CONSTRAINT pole_id_oblasti_fkey FOREIGN KEY (id_oblasti) REFERENCES public.oblast(id);


--
-- Name: tah_id_pole_fkey; Type: FK CONSTRAINT; Schema: public; Owner: petr
--

ALTER TABLE ONLY public.tah
    ADD CONSTRAINT tah_id_pole_fkey FOREIGN KEY (id_pole) REFERENCES public.pole(id);


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

