CREATE TRIGGER spust_po_oznaceni_tahu
  AFTER INSERT
  ON public.tah
  FOR EACH ROW
  EXECUTE PROCEDURE public.zpracuj_po_oznaceni_tahu();