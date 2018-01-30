
WHENEVER SQLERROR EXIT ROLLBACK ;

DECLARE
   lv_count NUMBER := 0;
   lv_err EXCEPTION;
BEGIN
   SELECT count(*)
     INTO lv_count
     FROM USER_TAB_COLUMNS
    WHERE table_name = 'EMP'
	  AND column_name = 'BONUS';
     IF lv_count < 1 THEN
       RAISE lv_err;
     END IF;
EXCEPTION
    WHEN lv_err THEN
      raise_application_error(-20000, 'Column EMP.BONUS not created');
END;
/
exit