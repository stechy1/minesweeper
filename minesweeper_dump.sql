--
-- PostgreSQL database dump
--

-- Dumped FROM database version 9.5.12
-- Dumped by pg_dump version 9.5.12

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: je_dohrano(text, integer); Type: FUNCTION; Schema: public; Owner: petr
--

CREATE FUNCTION public.je_dohrano(_zdroj text, _id_pole integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$BEGIN
	if _zdroj = 'tah' THEN
		return exists (
			SELECT distinct hra.id
			FROM tah
			INNER JOIN pole ON pole.id = _id_pole
			INNER JOIN oblast ON oblast.id = pole.id_oblasti
			INNER JOIN hra ON hra.id_oblasti = oblast.id
			WHERE hra.id_stav != 1
		);
	elsif _zdroj = 'mina' THEN
		return exists (
			SELECT distinct hra.id
			FROM mina
			INNER JOIN pole ON pole.id = _id_pole
			INNER JOIN oblast ON oblast.id = pole.id_oblasti
			INNER JOIN hra ON hra.id_oblasti = oblast.id
			WHERE hra.id_stav != 1
		);
	END if;

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
	if (pole_r.hodnota != 0) THEN
		return;
	END if;

	for tmp_x IN pole_r.x - 1 .. pole_r.x + 1 loop
		for tmp_y IN pole_r.y - 1 .. pole_r.y + 1 loop
			-- Pokud jsem na sve vlastni pozici --> skip
			continue WHEN (pole_r.x = tmp_x AND pole_r.y = tmp_y);

			-- Pokud pole neexistuje, jsem za hranici hraciho pole --> skip
			continue WHEN (
				not exists(
					SELECT *
					FROM pole
					WHERE pole.x = tmp_x
						AND pole.y = tmp_y
						AND pole.hodnota >= 0
						AND pole.id_oblasti = pole_r.id_oblasti
					)
				);

			-- Pokud jiz tah v sousedstvi existuje --> skip
			continue WHEN (
				EXISTS (
					SELECT tah.cas
					FROM pole
					INNER JOIN tah
					ON tah.id_pole = pole.id
					WHERE pole.x = tmp_x AND pole.y = tmp_y AND pole.id_oblasti = pole_r.id_oblasti
					)
				);

			-- Pokud jiz oznacena mina v sousedstvi existuje --> skip
			continue WHEN (
				EXISTS (
					SELECT mina.cas
					FROM pole
					INNER JOIN mina
					ON mina.id_pole = pole.id
					WHERE pole.x = tmp_x AND pole.y = tmp_y AND pole.id_oblasti = pole_r.id_oblasti
					)
				);

			-- Ziskam si ID sousedniho pole
			SELECT pole.id
			FROM pole
			INTO sousedni_id
			WHERE pole.x = tmp_x
				AND pole.y = tmp_y
				AND pole.hodnota != -1
				AND pole.id_oblasti = pole_r.id_oblasti;
			-- Tímto se zajisti neprima rekurze, takze budu vkladat sousedni tahy
			INSERT INTO tah VALUES (sousedni_id);
		END loop;
	END loop;
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
		SELECT pole.id_oblasti
		FROM pole
		WHERE pole.id = _id_pole AND pole.hodnota = -1);
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
	SELECT kod INTO stary FROM "POKUS" ORDER BY kod desc limit 1;
	novy := stary + 1;
	INSERT INTO "POKUS" (kod, hodnota) VALUES (novy, h);
exception WHEN others THEN
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
		SELECT pole.id, pole.hodnota, pole.x
		FROM pole
		WHERE pole.id_oblasti = oblast_id AND pole.y = radek
		ORDER BY pole.x ASC;
	radek RECORD;
	vystup text := '';
	entry character(1) := '?';
BEGIN
	OPEN radek_cursor(oblast_id, cislo_radku);

	LOOP
      FETCH radek_cursor INTO radek;
      EXIT WHEN NOT FOUND;

      	if exists (SELECT * FROM mina WHERE mina.id_pole = radek.id) THEN
      		-- mina je oznacena
      		vystup := vystup || '+';
      	elsif exists (SELECT * FROM tah WHERE tah.id_pole = radek.id) THEN
      		-- prazdne pole je oznaceno
		if radek.hodnota = -1 THEN
			vystup := vystup || '+';
		ELSE
			vystup := vystup || radek.hodnota::text;
		END if;
      	ELSE
      		vystup := vystup || entry;
      	END if;

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
	if NEW.obtiznost = 'zacatecnik' or NEW.obtiznost = 'pokrocily' or NEW.obtiznost = 'expert' THEN
		SELECT obtiznost.radku, obtiznost.sloupcu, obtiznost.min
		into existujici_obtiznost
		FROM obtiznost
		WHERE obtiznost.nazev = NEW.obtiznost;

		NEW.radku := existujici_obtiznost.radku;
		NEW.sloupcu := existujici_obtiznost.sloupcu;
		NEW.min := existujici_obtiznost.min;

		return NEW;
	END if;

	SELECT omezeni.hodnota into tmp_hodnota FROM omezeni WHERE popisek = 'minimalni velikost';
	if NEW.radku < tmp_hodnota or NEW.sloupcu < tmp_hodnota THEN
		RAISE EXCEPTION 'Oblast je prilis mala' USING
		hint = 'Pocet radku nebo sloupcu je prilis maly';
	END if;

	SELECT omezeni.hodnota into tmp_hodnota FROM omezeni WHERE popisek = 'maximalni velikost';
	if NEW.radku > tmp_hodnota or NEW.sloupcu > tmp_hodnota THEN
		RAISE EXCEPTION 'Oblast je prilis velka' USING
		hint = 'Pocet radku nebo sloupcu je prilis veliky';
	END if;

	SELECT omezeni.hodnota into tmp_hodnota FROM omezeni WHERE popisek = 'maximum min';
	if NEW.min > tmp_hodnota or NEW.min > NEW.sloupcu * NEW.radku THEN
		RAISE EXCEPTION 'Tolik min se do oblasti nevejde!' USING
		hint = 'Snizte pocet min';
	END if;

	SELECT omezeni.hodnota into tmp_hodnota FROM omezeni WHERE popisek = 'minimum min';
	if NEW.min < tmp_hodnota THEN
		RAISE EXCEPTION 'Prilis malo min' USING
		hint = 'Zvyste pocet min';
	END if;

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
	for tmp_x IN 1 .. _sloupcu loop
		for tmp_y IN 1 .. _radku loop
			-- vyfiltruji pole, na kterem je mina - na tomto poli prazdnou oblast nepocitam
			continue WHEN exists (SELECT id FROM pole WHERE pole.id_oblasti = _oblast_id AND pole.hodnota = -1 AND pole.x = tmp_x AND pole.y = tmp_y);

			-- tento SELECT mi vybere vsechna zaminovana policka v 8-okoli
			SELECT count(*)
			into tmp_8_okoli
			FROM pole
			WHERE pole.id_oblasti = _oblast_id
				AND (pole.x between tmp_x - 1 AND tmp_x + 1)
				AND (pole.y between tmp_y - 1 AND tmp_y + 1)
				AND pole.hodnota = -1;
			INSERT INTO pole (x, y, hodnota, id_oblasti) VALUES (tmp_x, tmp_y, tmp_8_okoli, _oblast_id);
		END loop; -- tmp_y
	END loop; -- tmp_x
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
		if not exists (SELECT id FROM pole WHERE pole.id_oblasti = NEW.id AND pole.x = rand_x AND pole.y = rand_y) THEN
			INSERT INTO pole (x, y, hodnota, id_oblasti) VALUES (rand_x, rand_y, -1, NEW.id);
			counter := counter + 1;
		END if; -- pole je prazdne
	END loop; -- counter

	PERFORM spocitej_oblast(NEW.id, NEW.sloupcu, NEW.radku);

	INSERT INTO hra (prvni_tah, posledni_tah, id_stav, id_oblasti)
		VALUES (NULL, NULL, 1, NEW.id);

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
	SELECT pole.id_oblasti into oblast_id FROM pole WHERE pole.id = NEW.id_pole;

	-- Aktualizace zaznamu o prvni tahu ve hre, pokud se jedna o prvni tah
	UPDATE hra SET prvni_tah = NEW.id_pole WHERE hra.id_oblasti = oblast_id AND hra.prvni_tah IS NULL;

	PERFORM odkryj_pole(NEW.id_pole);

	-- Aktualizace zaznamu o poslednim tahu ve hre
	UPDATE hra SET posledni_tah = NEW.id_pole WHERE hra.id_oblasti = oblast_id;

	SELECT vyhra(NEW.id_pole) INTO vyhrano;

	if vyhrano THEN
		PERFORM oznac_miny(oblast_id);
		UPDATE hra SET id_stav = 2 WHERE hra.id_oblasti = oblast_id;
		RAISE NOTICE 'Konec hry' USING
		hint = 'Gratuluji k uspesnemu procisteni herniho pole';
	END if;

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
	if (dohrano) THEN
		RAISE EXCEPTION 'Hra jiz byla ukoncena' USING
		hint = 'Vytvorte si novou hru pro dalsi hrani.';
		return NULL;
	END if;

	-- Pokud jiz mam minu oznacenou, tak oznaceni zrusim
	if EXISTS (SELECT * FROM mina WHERE mina.id_pole = NEW.id_pole) THEN
		DELETE FROM mina WHERE mina.id_pole = NEW.id_pole;
		return NULL;
	END if;

	-- Pokud je toto pole oznaceno jako odehrany tah, nic se nestane
	if EXISTS (SELECT * FROM tah WHERE tah.id_pole = NEW.id_pole) THEN
		RAISE EXCEPTION 'Neplatna mina' USING
		hint = 'Minu nelze oznacit na jiz odehranem poli';
		return NULL;
	END if;

	SELECT mnoho_min(NEW.id_pole) INTO je_mnoho_min;
	if (je_mnoho_min) THEN
		RAISE WARNING 'Nelze oznacit vice zaminovanych poli, nez kolik je min v oblasti' USING
		hint = 'Vypada to, ze jste oznacili miny i tam, kde nejsou.';

		return NULL;
	END if;

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
	if (dohrano) THEN
		RAISE EXCEPTION 'Hra jiz byla ukoncena' USING
		hint = 'Vytvorte si novou hru pro dalsi hrani.';
		return NULL;
	END if;

	-- Pokud je toto pole oznaceno jako mina
	if EXISTS (SELECT * FROM mina WHERE mina.id_pole = NEW.id_pole) THEN
		RAISE EXCEPTION 'Neplatny tah' USING
		hint = 'Tah nelze zahrat na oznacene mine';
		return NULL;
	END if;

	SELECT odkryta_mina(NEW.id_pole) into nasel_minu;
	if (nasel_minu) THEN

		SELECT pole.id_oblasti into oblast_id FROM pole WHERE pole.id = NEW.id_pole;
		UPDATE hra SET id_stav = 3 WHERE hra.id_oblasti = oblast_id;

		RAISE INFO 'Konec hry' USING
		hint = 'Odkryl jste neoznacenou minu. Konec hry';
	END if;

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
    ( SELECT COUNT(mina.id_pole) AS count
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

INSERT INTO public.hra (id, prvni_tah, posledni_tah, id_stav, id_oblasti) VALUES (3, 136, 138, 2, 4);
INSERT INTO public.hra (id, prvni_tah, posledni_tah, id_stav, id_oblasti) VALUES (2, 7, 7, 3, 2);
INSERT INTO public.hra (id, prvni_tah, posledni_tah, id_stav, id_oblasti) VALUES (4, 240, 166, 3, 5);


--
-- Name: hra_id_seq; Type: SEQUENCE SET; Schema: public; Owner: petr
--

SELECT pg_catalog.setval('public.hra_id_seq', 4, true);


--
-- Data for Name: mina; Type: TABLE DATA; Schema: public; Owner: petr
--

INSERT INTO public.mina (id_pole, cas) VALUES (83, '2018-04-16 16:10:11.667967');
INSERT INTO public.mina (id_pole, cas) VALUES (170, '2018-04-16 16:12:56.011844');
INSERT INTO public.mina (id_pole, cas) VALUES (180, '2018-04-16 16:13:18.69759');


--
-- Data for Name: oblast; Type: TABLE DATA; Schema: public; Owner: petr
--

INSERT INTO public.oblast (id, radku, sloupcu, min, obtiznost) VALUES (2, 9, 9, 10, 'zacatecnik');
INSERT INTO public.oblast (id, radku, sloupcu, min, obtiznost) VALUES (4, 9, 9, 1, 'vlastni');
INSERT INTO public.oblast (id, radku, sloupcu, min, obtiznost) VALUES (5, 9, 9, 10, 'zacatecnik');


--
-- Name: oblast_id_seq; Type: SEQUENCE SET; Schema: public; Owner: petr
--

SELECT pg_catalog.setval('public.oblast_id_seq', 5, true);


--
-- Data for Name: obtiznost; Type: TABLE DATA; Schema: public; Owner: petr
--

INSERT INTO public.obtiznost (id, nazev, radku, sloupcu, min) VALUES (1, 'zacatecnik', 9, 9, 10);
INSERT INTO public.obtiznost (id, nazev, radku, sloupcu, min) VALUES (2, 'pokrocily', 16, 16, 40);
INSERT INTO public.obtiznost (id, nazev, radku, sloupcu, min) VALUES (3, 'expert', 16, 30, 99);


--
-- Name: obtiznost_id_seq; Type: SEQUENCE SET; Schema: public; Owner: petr
--

SELECT pg_catalog.setval('public.obtiznost_id_seq', 3, true);


--
-- Data for Name: omezeni; Type: TABLE DATA; Schema: public; Owner: petr
--

INSERT INTO public.omezeni (popisek, hodnota) VALUES ('minimalni velikost                                ', 9);
INSERT INTO public.omezeni (popisek, hodnota) VALUES ('maximalni velikost                                ', 100);
INSERT INTO public.omezeni (popisek, hodnota) VALUES ('minimum min                                       ', 1);


--
-- Data for Name: pole; Type: TABLE DATA; Schema: public; Owner: petr
--

INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (2, 3, 6, -1, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (3, 8, 6, -1, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (4, 9, 9, -1, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (5, 6, 3, -1, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (6, 5, 9, -1, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (7, 7, 6, -1, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (8, 6, 9, -1, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (9, 2, 1, -1, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (10, 7, 7, -1, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (11, 5, 5, -1, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (12, 1, 1, 1, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (13, 1, 2, 1, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (14, 1, 3, 0, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (15, 1, 4, 0, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (16, 1, 5, 0, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (17, 1, 6, 0, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (18, 1, 7, 0, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (19, 1, 8, 0, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (20, 1, 9, 0, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (21, 2, 2, 1, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (22, 2, 3, 0, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (23, 2, 4, 0, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (24, 2, 5, 1, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (25, 2, 6, 1, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (26, 2, 7, 1, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (27, 2, 8, 0, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (28, 2, 9, 0, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (29, 3, 1, 1, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (30, 3, 2, 1, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (31, 3, 3, 0, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (32, 3, 4, 0, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (33, 3, 5, 1, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (34, 3, 7, 1, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (35, 3, 8, 0, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (36, 3, 9, 0, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (37, 4, 1, 0, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (38, 4, 2, 0, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (39, 4, 3, 0, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (40, 4, 4, 1, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (41, 4, 5, 2, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (42, 4, 6, 2, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (43, 4, 7, 1, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (44, 4, 8, 1, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (45, 4, 9, 1, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (46, 5, 1, 0, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (47, 5, 2, 1, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (48, 5, 3, 1, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (49, 5, 4, 2, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (50, 5, 6, 1, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (51, 5, 7, 0, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (52, 5, 8, 2, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (53, 6, 1, 0, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (54, 6, 2, 1, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (55, 6, 4, 2, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (56, 6, 5, 2, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (57, 6, 6, 3, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (58, 6, 7, 2, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (59, 6, 8, 3, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (60, 7, 1, 0, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (61, 7, 2, 1, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (62, 7, 3, 1, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (63, 7, 4, 1, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (64, 7, 5, 2, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (65, 7, 8, 2, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (66, 7, 9, 1, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (67, 8, 1, 0, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (68, 8, 2, 0, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (69, 8, 3, 0, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (70, 8, 4, 0, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (71, 8, 5, 2, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (72, 8, 7, 3, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (73, 8, 8, 2, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (74, 8, 9, 1, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (75, 9, 1, 0, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (76, 9, 2, 0, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (77, 9, 3, 0, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (78, 9, 4, 0, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (79, 9, 5, 1, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (80, 9, 6, 1, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (81, 9, 7, 1, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (82, 9, 8, 1, 2);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (83, 7, 2, -1, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (84, 1, 1, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (85, 1, 2, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (86, 1, 3, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (87, 1, 4, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (88, 1, 5, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (89, 1, 6, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (90, 1, 7, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (91, 1, 8, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (92, 1, 9, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (93, 2, 1, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (94, 2, 2, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (95, 2, 3, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (96, 2, 4, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (97, 2, 5, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (98, 2, 6, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (99, 2, 7, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (100, 2, 8, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (101, 2, 9, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (102, 3, 1, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (103, 3, 2, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (104, 3, 3, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (105, 3, 4, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (106, 3, 5, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (107, 3, 6, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (108, 3, 7, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (109, 3, 8, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (110, 3, 9, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (111, 4, 1, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (112, 4, 2, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (113, 4, 3, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (114, 4, 4, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (115, 4, 5, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (116, 4, 6, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (117, 4, 7, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (118, 4, 8, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (119, 4, 9, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (120, 5, 1, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (121, 5, 2, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (122, 5, 3, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (123, 5, 4, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (124, 5, 5, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (125, 5, 6, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (126, 5, 7, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (127, 5, 8, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (128, 5, 9, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (129, 6, 1, 1, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (130, 6, 2, 1, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (131, 6, 3, 1, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (132, 6, 4, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (133, 6, 5, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (134, 6, 6, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (135, 6, 7, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (136, 6, 8, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (137, 6, 9, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (138, 7, 1, 1, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (139, 7, 3, 1, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (140, 7, 4, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (141, 7, 5, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (142, 7, 6, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (143, 7, 7, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (144, 7, 8, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (145, 7, 9, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (146, 8, 1, 1, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (147, 8, 2, 1, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (148, 8, 3, 1, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (149, 8, 4, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (150, 8, 5, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (151, 8, 6, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (152, 8, 7, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (153, 8, 8, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (154, 8, 9, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (155, 9, 1, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (156, 9, 2, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (157, 9, 3, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (158, 9, 4, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (159, 9, 5, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (160, 9, 6, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (161, 9, 7, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (162, 9, 8, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (163, 9, 9, 0, 4);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (164, 3, 9, -1, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (165, 2, 1, -1, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (166, 3, 3, -1, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (167, 3, 5, -1, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (168, 7, 1, -1, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (169, 5, 2, -1, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (170, 7, 7, -1, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (171, 4, 1, -1, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (172, 6, 2, -1, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (173, 6, 9, -1, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (174, 1, 1, 1, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (175, 1, 2, 1, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (176, 1, 3, 0, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (177, 1, 4, 0, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (178, 1, 5, 0, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (179, 1, 6, 0, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (180, 1, 7, 0, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (181, 1, 8, 0, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (182, 1, 9, 0, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (183, 2, 2, 2, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (184, 2, 3, 1, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (185, 2, 4, 2, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (186, 2, 5, 1, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (187, 2, 6, 1, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (188, 2, 7, 0, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (189, 2, 8, 1, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (190, 2, 9, 1, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (191, 3, 1, 2, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (192, 3, 2, 3, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (193, 3, 4, 2, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (194, 3, 6, 1, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (195, 3, 7, 0, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (196, 3, 8, 1, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (197, 4, 2, 3, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (198, 4, 3, 2, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (199, 4, 4, 2, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (200, 4, 5, 1, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (201, 4, 6, 1, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (202, 4, 7, 0, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (203, 4, 8, 1, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (204, 4, 9, 1, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (205, 5, 1, 3, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (206, 5, 3, 2, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (207, 5, 4, 0, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (208, 5, 5, 0, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (209, 5, 6, 0, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (210, 5, 7, 0, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (211, 5, 8, 1, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (212, 5, 9, 1, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (213, 6, 1, 3, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (214, 6, 3, 2, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (215, 6, 4, 0, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (216, 6, 5, 0, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (217, 6, 6, 1, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (218, 6, 7, 1, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (219, 6, 8, 2, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (220, 7, 2, 2, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (221, 7, 3, 1, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (222, 7, 4, 0, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (223, 7, 5, 0, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (224, 7, 6, 1, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (225, 7, 8, 2, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (226, 7, 9, 1, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (227, 8, 1, 1, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (228, 8, 2, 1, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (229, 8, 3, 0, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (230, 8, 4, 0, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (231, 8, 5, 0, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (232, 8, 6, 1, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (233, 8, 7, 1, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (234, 8, 8, 1, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (235, 8, 9, 0, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (236, 9, 1, 0, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (237, 9, 2, 0, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (238, 9, 3, 0, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (239, 9, 4, 0, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (240, 9, 5, 0, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (241, 9, 6, 0, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (242, 9, 7, 0, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (243, 9, 8, 0, 5);
INSERT INTO public.pole (id, x, y, hodnota, id_oblasti) VALUES (244, 9, 9, 0, 5);


--
-- Name: pole_id_seq; Type: SEQUENCE SET; Schema: public; Owner: petr
--

SELECT pg_catalog.setval('public.pole_id_seq', 244, true);


--
-- Data for Name: stav; Type: TABLE DATA; Schema: public; Owner: petr
--

INSERT INTO public.stav (id, popis) VALUES (1, 'rozehrana');
INSERT INTO public.stav (id, popis) VALUES (2, 'uspesne ukoncena');
INSERT INTO public.stav (id, popis) VALUES (3, 'neuspesne ukoncena');


--
-- Name: stav_id_seq; Type: SEQUENCE SET; Schema: public; Owner: petr
--

SELECT pg_catalog.setval('public.stav_id_seq', 3, true);


--
-- Data for Name: tah; Type: TABLE DATA; Schema: public; Owner: petr
--

INSERT INTO public.tah (id_pole, cas) VALUES (7, '2018-04-16 15:59:43.05074');
INSERT INTO public.tah (id_pole, cas) VALUES (136, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (126, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (116, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (106, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (96, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (86, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (85, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (84, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (93, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (94, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (95, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (87, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (88, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (89, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (90, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (91, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (92, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (100, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (99, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (98, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (97, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (105, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (104, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (103, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (102, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (111, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (112, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (113, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (114, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (115, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (107, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (108, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (109, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (101, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (110, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (118, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (117, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (125, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (124, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (123, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (122, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (121, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (120, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (129, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (130, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (131, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (132, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (133, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (134, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (141, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (140, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (139, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (148, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (149, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (150, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (142, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (143, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (144, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (137, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (127, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (119, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (128, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (145, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (153, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (152, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (151, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (159, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (158, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (157, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (147, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (156, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (146, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (155, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (160, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (161, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (162, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (154, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (163, '2018-04-16 16:06:43.302499');
INSERT INTO public.tah (id_pole, cas) VALUES (135, '2018-04-16 16:09:16.877395');
INSERT INTO public.tah (id_pole, cas) VALUES (138, '2018-04-16 16:10:11.667967');
INSERT INTO public.tah (id_pole, cas) VALUES (240, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (230, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (221, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (222, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (214, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (215, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (206, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (207, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (198, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (199, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (200, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (208, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (201, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (209, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (202, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (194, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (195, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (187, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (188, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (179, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (178, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (177, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (176, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (175, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (183, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (184, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (185, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (186, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (181, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (182, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (189, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (190, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (196, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (203, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (210, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (211, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (217, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (218, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (219, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (216, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (223, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (224, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (231, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (232, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (239, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (229, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (220, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (228, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (237, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (227, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (236, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (238, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (241, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (233, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (242, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (234, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (243, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (235, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (225, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (226, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (244, '2018-04-16 16:13:57.778018');
INSERT INTO public.tah (id_pole, cas) VALUES (166, '2018-04-16 16:14:55.612939');


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

