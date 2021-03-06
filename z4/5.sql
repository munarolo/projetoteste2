/*
TRUNCATE TABLE TMP_TMP_DASHFI_14750_13_202815;
DROP TABLE TMP_TMP_DASHFI_14750_13_200904;
SELECT COUNT(1) FROM TMP_TMP_DASHFI_14750_13_200904;
SELECT cod_sit, count(1) FROM TMP_TMP_DASHFI_14750_13_200904 group by cod_sit;
SELECT * FROM TMP_TMP_DASHFI_14750_13_200904 ;
*/
DECLARE P_MESREFINI   CHAR(6) := '201905';
        P_MESREFFIM   CHAR(6) := '201905';
        P_OPERADORA   CHAR(1000) := ' AND COD_HOLDING IN (''TLA'')';
        P_UF          CHAR(2) := '';
        P_CSP         CHAR(2) := '31';
        P_CICLOINI    CHAR(2) := '';
        P_CICLOFIM    CHAR(2) := '';
        P_SITUACAO    CHAR(2) := '0';
        P_STATUS      CHAR(10) := 'Todos';
        P_VISAO       CHAR(10) := 'PIVOTAB'; 
        P_CAMPO       CHAR(10) := 'VALOR';
        P_TABELA_FATO VARCHAR2(200) := 'TMP_DASHFI_14703_04_151235';
        V_RETORNO     CLOB;
        P_TAB_FILTROS VARCHAR2(200) ;
        v_cur         SYS_REFCURSOR ;
BEGIN
    --PKG_DASHBOARD_FISCAL.SP_SEL_SELECIONAR_BATIMENTO1(P_MESREFINI, P_MESREFFIM, P_OPERADORA, P_UF, P_CSP, P_CICLOINI, P_CICLOFIM, P_SITUACAO, P_STATUS, P_VISAO, P_CAMPO, P_TABELA_FATO, v_cur);
    --PKG_DASHBOARD_FISCAL.SP_SEL_BATIMENTO1_GERATAB(P_MESREFINI, P_MESREFFIM, P_OPERADORA, P_UF, P_CSP, P_CICLOINI, P_CICLOFIM, P_SITUACAO, P_STATUS, P_VISAO, P_CAMPO, P_TAB_FILTROS);
    --PKG_DASHBOARD_FISCAL.SP_SEL_GERATAB(P_MESREFINI, P_MESREFFIM, P_OPERADORA, P_UF, P_CSP, P_CICLOINI, P_CICLOFIM, P_SITUACAO, P_STATUS, V_RETORNO);
    PKG_DASHBOARD_FISCAL.SP_SEL_BATIMENTO(P_MESREFINI, P_MESREFFIM, P_OPERADORA, P_UF, P_CSP, P_CICLOINI, P_CICLOFIM, P_SITUACAO, P_STATUS, V_CUR);
    --PKG_DASHBOARD_FISCAL.SP_SEL_GRAFICOBAIDU(P_MESREFINI, P_MESREFFIM, P_OPERADORA, P_UF, P_CSP, P_CICLOINI, P_CICLOFIM, P_SITUACAO, P_STATUS, V_RETORNO);
    --PKG_DASHBOARD_FISCAL.SP_SEL_GERENCIAL1_RESUMIDO(P_MESREFINI, P_MESREFFIM, P_OPERADORA, P_UF, P_CSP, P_CICLOINI, P_CICLOFIM, P_SITUACAO, P_STATUS, V_CUR);
    --PKG_DASHBOARD_FISCAL.SP_SEL_GERENCIAL2(P_MESREFINI, P_MESREFFIM, P_OPERADORA, P_UF, P_CSP, P_CICLOINI, P_CICLOFIM, P_SITUACAO, P_STATUS, V_CUR);
    --PKG_DASHBOARD_FISCAL.SP_SEL_SELECIONAR_BATIMENTO3(P_MESREFINI, P_MESREFFIM, P_OPERADORA, P_UF, P_CSP, P_CICLOINI, P_CICLOFIM, P_SITUACAO, P_STATUS, V_CUR);
    --dbms_output.put_line(P_TAB_FILTROS);
    dbms_output.put_line(V_RETORNO);
END;

TRUNCATE TABLE TMP_DASHFI_14753_18_15551905;
DROP TABLE TMP_DASHFI_14753_18_15551905;

DECLARE P_CSP       VARCHAR2(2) := '';
        P_MESREF    VARCHAR2(6) := '201003';
        P_GR_SIT    VARCHAR2(20) := '';
        P_TAB_FATO  VARCHAR2(200) := 'TMP_DASHFI_14693_24_221831';
        P_SEQ       NUMBER(10);
        v_cur       SYS_REFCURSOR ;
BEGIN
    PKG_DASHBOARD_FISCAL.SP_SEL_GERENCIAL1_RESUMIDO(P_CSP, P_MESREF, P_GR_SIT, P_TAB_FATO, v_cur);
    LOOP
      FETCH v_cur INTO P_SEQ;
      EXIT WHEN v_cur%NOTFOUND;
      dbms_output.put_line(TO_CHAR(P_SEQ));
    END LOOP;
    CLOSE v_cur;
END;

----------------UF------------------------
DECLARE 
  v_cur SYS_REFCURSOR;
  P_CSP CHAR(2) := '14';
  P_MESREF VARCHAR2(6) := '';
  P_UF CHAR(2);
  P_QTD NUMBER;
  P_TAB_FATO VARCHAR(100) := 'TMP_DASHFI_14598_10_221024';
BEGIN 
  PKG_DASHBOARD_FISCAL.SP_SEL_ACIONAMENTOS_UF( P_CSP, P_MESREF, P_TAB_FATO, v_cur);
  LOOP
    FETCH v_cur INTO P_UF, P_QTD;
    EXIT WHEN v_cur%NOTFOUND;
    dbms_output.put_line(P_UF || ' - ' || P_QTD);
  END LOOP;
  CLOSE v_cur;
END;

----------------LAYOUT------------------------
DECLARE 
  v_cur SYS_REFCURSOR;
  P_USERID CHAR(8) := 'MMUNAROL';
  P_VALOR NUMBER(10,2) := 0;
BEGIN 
  PKG_DASHBOARD_FISCAL.SP_SEL_LAYOUT( P_USERID, v_cur);
  LOOP
    FETCH v_cur INTO P_USERID;
    EXIT WHEN v_cur%NOTFOUND;
    dbms_output.put_line('USER:' || P_USERID || 'VALOR:' || P_VALOR);
  END LOOP;
  CLOSE v_cur;
END;

----------------grafico----------------------
DECLARE 
  V_RETORNO CLOB;
BEGIN 
  PKG_DASHBOARD_FISCAL.SP_SEL_GRAFICO('TMP_DASHFI_14599_11_220637', V_RETORNO);
  dbms_output.put_line(V_RETORNO);
END;       

DECLARE 
  V_RETORNO CLOB;
BEGIN 
  PKG_DASHBOARD_FISCAL.SP_SEL_GRAFICOBAIDU(V_RETORNO);
  dbms_output.put_line(V_RETORNO);
END;       


--SELECT * FROM T_TOT_DASHBOARD_FISCAL
--DELETE FROM T_TOT_DASHBOARD_FISCAL
--commit

BEGIN 
       PKG_DASHBOARD_FISCAL.SP_SEL_BATIMENTO1_LIMPATAB('TMP_DASHFI_14598_10_213117');
END;

--SELECT * FROM T_TOT_DASHBOARD_FISCAL 
--SELECT COUNT(1) FROM T_TOT_DASHBOARD_FISCAL 
--SELECT DISTINCT TAB_TEMP FROM T_TOT_DASHBOARD_FISCAL 
--SELECT CSP, MES_REFERENCIA, COUNT(1) FROM T_TOT_DASHBOARD_FISCAL GROUP BY CSP, MES_REFERENCIA order by 1,2

