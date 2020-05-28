SELECT * from SYS.USER_ERRORS where NAME = 'PKG_DASHBOARD_FISCAL' ;

CREATE OR REPLACE PACKAGE BODY PKG_DASHBOARD_FISCAL AS

    PROCEDURE SP_SEL_FILTROS_HOLDING( P_FILTROS OUT SYS_REFCURSOR )
    IS
      V_FILTROS SYS_REFCURSOR;
    BEGIN

      OPEN V_FILTROS FOR
           SELECT DISTINCT H.COD_HOLDING, HC.DES_HOLDING || '(' || H.DES_HOLDING || ')' AS DES_HOLDING
                  FROM HOLDING_GEF H
                  INNER JOIN SCH_C31DB00.T_EMPRESA_GEF E ON H.COD_HOLDING = E.SIGLA_HOLDING
                  INNER JOIN SCH_C31DB00.T_SIGLA_HOLDING HC ON H.COD_HOLDING = HC.SIGLA_HOLDING
                  WHERE E.TAG_CBEMP = 'S'
                  ORDER BY HC.DES_HOLDING || '(' || H.DES_HOLDING || ')';

          P_FILTROS := V_FILTROS;
   END;

   PROCEDURE SP_SEL_LAYOUT( 
     P_USER_ID CHAR, 
     P_FILTROS OUT SYS_REFCURSOR )
   IS
     V_FILTROS SYS_REFCURSOR;
     V_QTD NUMBER(1);
   BEGIN
     --SE NÃO EXISTIR LAYOUT PARA O USUÁRIO, CRIA LAYOUT PADRAO
     SELECT COUNT(1) INTO V_QTD FROM T_TOT_DASHBOARD_FISCAL_LAYOUT WHERE USER_ID = P_USER_ID;
     IF NVL(V_QTD,0) = 0  THEN
       INSERT INTO T_TOT_DASHBOARD_FISCAL_LAYOUT (USER_ID, VLR_SUPERIOR_INI, VLR_SUPERIOR_FIM, ID_SUPERIOR_COR, VLR_META, ID_META_COR, VLR_INFERIOR_INI, VLR_INFERIOR_FIM, ID_INFERIOR_COR)
              SELECT P_USER_ID, VLR_SUPERIOR_INI, VLR_SUPERIOR_FIM, ID_SUPERIOR_COR, VLR_META, ID_META_COR, VLR_INFERIOR_INI, VLR_INFERIOR_FIM, ID_INFERIOR_COR
                     FROM T_TOT_DASHBOARD_FISCAL_LAYOUT 
                     WHERE USER_ID = 'PADRAO';
     END IF;

     OPEN V_FILTROS FOR
           SELECT VLR_SUPERIOR_INI, VLR_SUPERIOR_FIM, ID_SUPERIOR_COR, VLR_META, ID_META_COR, VLR_INFERIOR_INI, VLR_INFERIOR_FIM, ID_INFERIOR_COR 
                  FROM T_TOT_DASHBOARD_FISCAL_LAYOUT
                  WHERE USER_ID = P_USER_ID;
          P_FILTROS := V_FILTROS;
   END;

   PROCEDURE SP_UPD_LAYOUT(
     P_USER_ID          CHAR,
     P_VLR_SUPERIOR_INI NUMBER,
     P_VLR_SUPERIOR_FIM NUMBER,
     P_ID_SUPERIOR_COR  CHAR,
     P_VLR_META         NUMBER,
     P_ID_META_COR      CHAR,
     P_VLR_INFERIOR_INI NUMBER,
     P_VLR_INFERIOR_FIM NUMBER,
     P_ID_INFERIOR_COR  CHAR)
   IS
   BEGIN
     UPDATE T_TOT_DASHBOARD_FISCAL_LAYOUT SET 
            VLR_SUPERIOR_INI = P_VLR_SUPERIOR_INI, 
            VLR_SUPERIOR_FIM = P_VLR_SUPERIOR_FIM, 
            ID_SUPERIOR_COR  = P_ID_SUPERIOR_COR, 
            VLR_META         = P_VLR_META, 
            ID_META_COR      = P_ID_META_COR, 
            VLR_INFERIOR_INI = P_VLR_INFERIOR_INI, 
            VLR_INFERIOR_FIM = P_VLR_INFERIOR_FIM, 
            ID_INFERIOR_COR  = P_ID_INFERIOR_COR
        WHERE USER_ID = P_USER_ID;
        COMMIT;
   END;

    PROCEDURE SP_SEL_FILTROS_UF( P_FILTROS OUT SYS_REFCURSOR )
    IS
      V_FILTROS SYS_REFCURSOR;
    BEGIN

      OPEN V_FILTROS FOR
           SELECT DISTINCT COD_UF, NOM_UF, COD_UF || ' - ' || NOM_UF AS DES_UF
                  FROM SCH_C31DB00.T_UF
                  ORDER BY NOM_UF;

          P_FILTROS := V_FILTROS;
   END;

    PROCEDURE SP_SEL_FILTROS_GRUPO_SITUACAO( P_FILTROS OUT SYS_REFCURSOR )
    IS
      V_FILTROS SYS_REFCURSOR;
    BEGIN

      OPEN V_FILTROS FOR
           SELECT *
                  FROM SCH_DW_OI.T_GRUPO_SITUACAO
                  ORDER BY DES_GRUPO_SITUACAO;

          P_FILTROS := V_FILTROS;
   END;

    PROCEDURE SP_SEL_ACIONAMENTOS_UF( 
      P_CSP       CHAR,
      P_MESREF    CHAR,
      P_TAB_FATO  VARCHAR2,
      P_FILTROS   OUT SYS_REFCURSOR )
    IS
      V_FILTROS SYS_REFCURSOR;
    BEGIN

      OPEN V_FILTROS FOR 
           SELECT UF, SUM(nvl(QTD_ACIONAMENTOS,0)) QTD 
                   FROM T_TOT_DASHBOARD_FISCAL 
                   WHERE TAB_TEMP = P_TAB_FATO 
                         AND CSP = P_CSP 
                         AND MES_REFERENCIA = P_MESREF 
                   GROUP BY UF HAVING SUM(nvl(QTD_ACIONAMENTOS,0)) > 0 ORDER BY UF;
             
          P_FILTROS := V_FILTROS;
   END;

    PROCEDURE SP_SEL_GERENCIAL1_DETALHADO( 
      P_CSP       CHAR := NULL,
      P_MESREF    CHAR := NULL,
      P_GR_SIT    VARCHAR2 := NULL,
      P_TAB_FATO  VARCHAR2,
      P_FILTROS   OUT SYS_REFCURSOR )
    IS
      V_FILTROS SYS_REFCURSOR;
    BEGIN

      OPEN V_FILTROS FOR 
           SELECT DSH.CSP, 
                  DSH.DES_HOLDING       AS OPERADORA, 
                  DSH.UF, 
                  DSH.MES_REFERENCIA, 
                  DSH.CICLO             AS CICLO_NF, 
                  RPAD('',50,' ')       AS NOME_ARQUIVO, 
                  DSH.DES_SITUACAO      AS SITUACAO_GRUPO, 
                  DSH.QTD_ACIONAMENTOS, 
                  DSH.VLR_RESUMO, 
                  DSH.VLR_TCOF
                FROM T_TOT_DASHBOARD_FISCAL DSH
                WHERE DSH.TAB_TEMP = P_TAB_FATO 
                      AND (DSH.CSP = P_CSP OR P_CSP IS NULL)
                      AND (DSH.MES_REFERENCIA = P_MESREF OR P_MESREF IS NULL)
                      AND (UPPER(DSH.DES_GRUPO_SITUACAO) = UPPER(P_GR_SIT) OR P_GR_SIT IS NULL)
                      AND DSH.DES_HOLDING IS NOT NULL
                ORDER BY 1;
             
          P_FILTROS := V_FILTROS;
   END;

   PROCEDURE SP_SEL_GERENCIAL1_RESUMIDO( 
      P_CSP       CHAR := NULL,
      P_MESREF    CHAR := NULL,
      P_GR_SIT    VARCHAR2 := NULL,
      P_TAB_FATO  VARCHAR2,
      P_FILTROS   OUT SYS_REFCURSOR )
    IS
      V_FILTROS SYS_REFCURSOR;
    BEGIN
      OPEN V_FILTROS FOR 
          SELECT PIV.CSP, PIV.OPERADORA, PIV.ANO_MES_REF_NF, PIV.CICLO, 
                 PIV.VLR_RESUMO, PIV.VLR_ACEITO, PIV.VLR_REJEITADO, PIV.VLR_RECEBIDO, PIV.VLR_PENDENTE,
                 ROUND(CASE WHEN NVL(VLR_TOTAL,0) = 0 THEN 0 ELSE (PIV.VLR_RESUMO    / VLR_TOTAL * 100) END, 2) AS PCT_RESUMO,
                 ROUND(CASE WHEN NVL(VLR_TOTAL,0) = 0 THEN 0 ELSE (PIV.VLR_ACEITO    / VLR_TOTAL * 100) END, 2) AS PCT_ACEITO,
                 ROUND(CASE WHEN NVL(VLR_TOTAL,0) = 0 THEN 0 ELSE (PIV.VLR_REJEITADO / VLR_TOTAL * 100) END, 2) AS PCT_REJEITADO,
                 ROUND(CASE WHEN NVL(VLR_TOTAL,0) = 0 THEN 0 ELSE (PIV.VLR_RECEBIDO  / VLR_TOTAL * 100) END, 2) AS PCT_RECEBIDO,
                 ROUND(CASE WHEN NVL(VLR_TOTAL,0) = 0 THEN 0 ELSE (PIV.VLR_PENDENTE  / VLR_TOTAL * 100) END, 2) AS PCT_PENDENTE
              FROM (
              SELECT *
                  FROM (
                        SELECT DSH.CSP, DSH.DES_HOLDING AS OPERADORA, DSH.MES_REFERENCIA AS ANO_MES_REF_NF, DSH.CICLO, nvl(DSH.DES_GRUPO_SITUACAO, 'VLR_TOTAL') AS DES_GRUPO_SITUACAO, /*SUM(DSH.VLR_RESUMO) VLR_RESUMO1, */ SUM(DSH.VLR_TCOF) VLR_TCOF 
                            FROM T_TOT_DASHBOARD_FISCAL DSH
                            WHERE DSH.TAB_TEMP = P_TAB_FATO 
                                  AND (DSH.CSP = P_CSP OR P_CSP IS NULL)
                                  AND (DSH.MES_REFERENCIA = P_MESREF OR P_MESREF IS NULL)
                                  AND (UPPER(DSH.DES_GRUPO_SITUACAO) = UPPER(P_GR_SIT) OR P_GR_SIT IS NULL)
                                  AND DSH.DES_HOLDING IS NOT NULL
                            GROUP BY cube(DSH.CSP, DSH.MES_REFERENCIA, DSH.DES_HOLDING, DSH.CICLO, DSH.DES_GRUPO_SITUACAO)
                               HAVING csp IS NOT NULL AND DES_HOLDING IS NOT NULL AND MES_REFERENCIA IS NOT NULL AND ciclo IS NOT NULL
                       ) DET
              PIVOT (
                        SUM(DET.VLR_TCOF)
                        FOR (DES_GRUPO_SITUACAO) IN ( 'Resumo' AS "VLR_RESUMO", 'Aceito' AS "VLR_ACEITO", 'Rejeitado' AS "VLR_REJEITADO", 'Recebido' AS "VLR_RECEBIDO", 'Pendente' AS "VLR_PENDENTE", 'VLR_TOTAL' AS "VLR_TOTAL")
                    )
              ORDER BY 1,2,3,4
              ) PIV;

      P_FILTROS := V_FILTROS;
   END;

   PROCEDURE SP_SEL_BATIMENTO1_LIMPATAB (
     P_TAB_FATO VARCHAR2
     )
   IS
   BEGIN
     DELETE FROM T_TOT_DASHBOARD_FISCAL WHERE TAB_TEMP = P_TAB_FATO;
   END;
   
   PROCEDURE SP_SEL_BATIMENTO1_GERATAB(
      P_MESREFINI CHAR,
      P_MESREFFIM CHAR,
      P_OPERADORA CHAR,
      P_UF CHAR,
      P_CSP CHAR,
      P_CICLOINI CHAR,
      P_CICLOFIM CHAR,
      P_SITUACAO CHAR,
      P_STATUS CHAR,
      P_VISAO CHAR := 'PIVOTAB',
      P_CAMPO CHAR := 'VALOR',
      P_TAB_FATO OUT VARCHAR2)
    IS
      --VARIAVEIS DE TRABALHO
      cols        clob; --PEGA AS COLUNAS QUE SERAO GERADAS NO PIVOT (MES_REFERENCIA)
      V_ANO       INTEGER;
      V_MES       INTEGER;
      V_CSP       CHAR(2) :='';
      V_MESREFINI CHAR(6);
      V_MESREFFIM CHAR(6);
      v_query     clob;
      v_querytot  CLOB;
      v_filtro_ciclo VARCHAR2(255) := '';
      v_filtro_situacao VARCHAR2(255) := '';
      v_filtro_status VARCHAR2(255) := '';
      --VARIAVEIS DOS CURSORES
      C_PIVOT     SYS_REFCURSOR;
      cnt         NUMBER;
      V_TAB_DASH VARCHAR2(100);
    BEGIN
      
    SELECT sps_NomeTabTemp('DASHFI') INTO V_TAB_DASH FROM DUAL;

    v_filtro_situacao := '';
    IF P_SITUACAO <> 'Todas' THEN
      v_filtro_situacao := ' AND UPPER(tgr.DES_GRUPO_SITUACAO) = ''' || UPPER(P_SITUACAO) || '''';
    END IF;

    v_filtro_status := '';
    IF P_STATUS <> 'Todos' THEN
      IF P_STATUS = 'OK' THEN
        v_filtro_status :=  ' AND (NVL(vlr_resumo,0) = NVL(vlr_tcof,0)) ';
      ELSE
        v_filtro_status :=  ' AND (NVL(vlr_resumo,0) <> NVL(vlr_tcof,0)) ';
      END IF;
    END IF;

    v_filtro_ciclo := '';
    IF LENGTH(rtrim(ltrim(nvl(P_CICLOINI,'')))) > 0 THEN
      v_filtro_ciclo := ' AND DET.CICLO >= ' || P_CICLOINI || ' AND DET.CICLO <= ' || P_CICLOFIM;
    END IF;

    SELECT COUNT(1) INTO cnt FROM user_tables WHERE table_name = 'tmp_pivot';
    IF cnt <> 0 THEN
      EXECUTE IMMEDIATE 'TRUNCATE TABLE tmp_pivot';
      EXECUTE IMMEDIATE 'DROP TABLE tmp_pivot';
    END IF;

    SELECT LISTAGG('''' || MES_REFERENCIA || ''' as "' || MES_REFERENCIA || '"', ',') WITHIN GROUP (ORDER BY MES_REFERENCIA) INTO   COLS
           FROM (SELECT DISTINCT MES_REFERENCIA FROM SOLICITACAO_CARGA_PRE_GFX WHERE mes_referencia BETWEEN P_MESREFINI AND P_MESREFFIM ORDER BY 1);

    --APAGA FATOS ANTERIORES (15 MINUTOS PARA TRAZ)
    DELETE FROM T_TOT_DASHBOARD_FISCAL WHERE dat_inclusao < SYSDATE-15/24/60;

    v_query := 'SELECT * FROM (
    SELECT ''' || V_TAB_DASH ||''' TAB_TEMP, 
           ''%%'' AS CSP,
           DET.SEQ_RECEPCAO,
           DET.DSN_RECEPCAO,
           DET.COD_HOLDING,
           DET.DES_HOLDING,
           DET.UF,
           DET.MES_REFERENCIA,
           DES_GRUPO_SITUACAO,
           DET.COD_SITUACAO,
           DET.DES_SITUACAO,
           nvl(DET.VLR_TCOF,0) VLR_TCOF,
           nvl(DET.VLR_RESUMO,0) VLR_RESUMO,
           NVL(DET.QTD_ACIONAMENTOS,0) QTD_ACIONAMENTOS,
           SYSDATE AS DAT_INCLUSAO,
           DET.CICLO
           FROM (SELECT AF.SEQ_RECEPCAO, AF.DSN_RECEPCAO, GFX.COD_HOLDING, GFX.DES_HOLDING,
                           GFX.UF,
                           GFX.MES_REFERENCIA MES_REFERENCIA,
                           GFX.CICLO,
                           CASE
                             WHEN GFX.VLR_RESUMO > 0          THEN 0
                             WHEN AF.DSN_RECEPCAO IS NULL     THEN 1
                             WHEN AF.COD_CRITICA2 <> 0        THEN 2
                             WHEN AF.STATUS_CRITPROT IS NULL  THEN 3
                             WHEN AF.STATUS_CRITPROT = ''FR'' THEN 4
                             WHEN AF.STATUS_CRITPROT = ''FJ'' THEN 5
                           END COD_SITUACAO,
                           CASE
                             WHEN GFX.VLR_RESUMO > 0          THEN ''Resumo''
                             WHEN AF.DSN_RECEPCAO IS NULL     THEN ''TCOF Não Encontrado''
                             WHEN AF.COD_CRITICA2 <> 0        THEN ''TCOF Criticado''
                             WHEN AF.STATUS_CRITPROT IS NULL  THEN ''Aguardando Protocolo''
                             WHEN AF.STATUS_CRITPROT = ''FR'' THEN ''TCOF Recebido''
                             WHEN AF.STATUS_CRITPROT = ''FJ'' THEN ''Mainframe Rejeitado''
                           END DES_SITUACAO,
                           GFX.NOME_REMESSA,
                           (SELECT COUNT(*)
                              FROM T_EMAIL_CONTROLEENVIO%%% E
                             WHERE AF.SEQ_RECEPCAO = E.ID_SEQ_RECEPCAO) +
                           (SELECT COUNT(*)
                              FROM T_EMAIL_CONTROLEENVIO_HIST%%% HE
                             WHERE AF.SEQ_RECEPCAO = HE.ID_SEQ_RECEPCAO) QTD_ACIONAMENTOS,
                           GFX.VLR_RESUMO,
                           AF.VLR_TOTAL_ARQ VLR_TCOF,
                           AF.COD_CRITICA2,
                           AF.STATUS_CRITPROT
                      FROM (SELECT SOL.COD_HOLDING,
                                   HC.DES_HOLDING,
                                   DET.UF,
                                   SOL.MES_REFERENCIA,
                                   DET.CICLO,
                                   DET.NOME_REMESSA,
                                   SUM(DET.VALOR_CONTABIL) VLR_RESUMO
                              FROM SOLICITACAO_CARGA_PRE_GFX%%% SOL
                             INNER JOIN T_SIGLA_HOLDING%%% HC    ON SOL.COD_HOLDING = HC.SIGLA_HOLDING
                             INNER JOIN RESUMO_FISCAL_GFX%%% DET ON SOL.ID_CARGA = DET.ID_CARGA AND SOL.TIPO_DEMONSTRATIVO = ''RESU''
                             WHERE SOL.MES_REFERENCIA BETWEEN '''||P_MESREFINI||''' AND '''||P_MESREFFIM||''' ' || P_OPERADORA || ' ' || P_UF || v_filtro_ciclo || ' 
                             GROUP BY SOL.COD_HOLDING,
                                      HC.DES_HOLDING,
                                      DET.UF,
                                      SOL.MES_REFERENCIA,
                                      DET.CICLO,
                                      DET.NOME_REMESSA) GFX
                      LEFT JOIN T_CTRL_ARQ_FISCAIS%%% AF
                        ON GFX.COD_HOLDING = AF.COD_CONTRATADA 
                           AND GFX.CICLO = AF.CICLO_NF
                       AND TO_CHAR(AF.MES_DIA_EMISSAO_NF, ''YYYYMM'') = GFX.MES_REFERENCIA
                       AND AF.STATUS_RECEPCAO <> 5
                       /*AND AF.SEQ_RECEPCAO IN
                           (SELECT MAX(MAF.SEQ_RECEPCAO) SEQ_RECEPCAO
                              FROM T_CTRL_ARQ_FISCAIS%%% MAF
                              WHERE MAF.COD_CONTRATADA = AF.COD_CONTRATADA
                                    AND TO_CHAR(MAF.MES_DIA_EMISSAO_NF, ''YYYYMM'') = TO_CHAR(AF.MES_DIA_EMISSAO_NF, ''YYYYMM'')
                                    AND MAF.CICLO_NF = AF.CICLO_NF
                                    AND MAF.STATUS_RECEPCAO <> 5)*/
                      INNER JOIN T_EMPRESA EMPCB ON AF.COD_EOT_CB = EMPCB.COD_EOTEMP AND EMPCB.COD_UFEMP = GFX.UF
                      ) DET ';

    v_query := v_query || ' INNER JOIN sch_dw_oi.t_grupo_situacao tgr ON tgr.cod_situacao = det.COD_SITUACAO ' || v_filtro_situacao;
    v_query := v_query || ' WHERE 0 = 0 ' || v_filtro_status || ')';

    V_CSP := P_CSP;
    IF P_CSP = '31' THEN v_querytot := replace(replace(v_query,'%%%',''),'%%','31'); END IF;
    IF P_CSP = '14' THEN v_querytot := replace(replace(v_query,'%%%','_BRT'),'%%','14'); END IF;
    IF P_CSP = '0' THEN v_querytot := replace(replace(v_query,'%%%','_BRT'),'%%','14') || ' union ' || replace(replace(v_query,'%%%',''),'%%','31'); V_CSP := '14';END IF;

    DELETE FROM T_TOT_DASHBOARD_FISCAL WHERE TAB_TEMP=V_TAB_DASH;

    --dbms_output.put_line( 'INSERT INTO T_TOT_DASHBOARD_FISCAL ' || v_querytot );
    EXECUTE IMMEDIATE 'INSERT INTO T_TOT_DASHBOARD_FISCAL ' || v_querytot;

    --INSERINDO GRUPOS DE SITUACAO QUE NAO EXISTEM NA TABELA FATO (MES_REF A MES_REF E CSP A CSP)
    SELECT min(mes_referencia), MAX(MES_REFERENCIA) INTO V_MESREFINI, V_MESREFFIM FROM T_TOT_DASHBOARD_FISCAL WHERE TAB_TEMP = V_TAB_DASH;
    V_MES := TO_NUMBER(SUBSTR(V_MESREFINI,5,2));
    V_ANO := TO_NUMBER(SUBSTR(V_MESREFINI,1,4));
    
    WHILE to_number(trim(TO_CHAR(V_ANO,'0000')) || trim(TO_CHAR(V_MES,'00'))) <= to_number(V_MESREFFIM)
    LOOP

      INSERT INTO T_TOT_DASHBOARD_FISCAL (TAB_TEMP, CSP, mes_referencia, DES_GRUPO_SITUACAO, vlr_TCOF, VLR_RESUMO, QTD_ACIONAMENTOS, DAT_INCLUSAO) 
             SELECT V_TAB_DASH, V_CSP, trim(TO_CHAR(V_ANO))||trim(TO_CHAR(V_MES,'00')), tgr.DES_GRUPO_SITUACAO, 0, 0, 0, SYSDATE 
                FROM sch_dw_oi.t_grupo_situacao tgr WHERE NOT EXISTS (SELECT 1 FROM T_TOT_DASHBOARD_FISCAL fato 
                                                                             WHERE TAB_TEMP = V_TAB_DASH AND fato.csp= V_CSP AND fato.mes_referencia = TO_CHAR(V_ANO)||TO_CHAR(V_MES,'00') AND fato.des_grupo_situacao=tgr.des_grupo_situacao);
      COMMIT;

      V_MES := V_MES + 1;
      IF V_MES > 12 THEN
        V_MES := 1;
        V_ANO := V_ANO + 1;
      END IF;

      IF TO_NUMBER(trim(TO_CHAR(V_ANO))||trim(TO_CHAR(V_MES,'00'))) > to_number(V_MESREFFIM) THEN
        IF P_CSP = V_CSP OR V_CSP = '31' THEN 
          EXIT; 
        ELSE
          V_CSP := '31';
          V_MES := TO_NUMBER(SUBSTR(V_MESREFINI,5,2));
          V_ANO := TO_NUMBER(SUBSTR(V_MESREFINI,1,4));
        END IF;
      END IF;

    END LOOP;

    P_TAB_FATO := TRIM(V_TAB_DASH);

   END;

   PROCEDURE SP_SEL_SELECIONAR_BATIMENTO1(
      P_MESREFINI CHAR,
      P_MESREFFIM CHAR,
      P_OPERADORA CHAR,
      P_UF CHAR,
      P_CSP CHAR,
      P_CICLOINI CHAR,
      P_CICLOFIM CHAR,
      P_SITUACAO CHAR,
      P_STATUS CHAR,
      P_VISAO CHAR := 'PIVOTAB',
      P_CAMPO CHAR := 'VALOR',
      P_TABELA_FATO VARCHAR2,
      P_FILTROS OUT SYS_REFCURSOR )
    IS
      --VARIAVEIS DE TRABALHO
      cols        clob; --PEGA AS COLUNAS QUE SERAO GERADAS NO PIVOT (MES_REFERENCIA)
      v_query     clob;
      --VARIAVEIS DOS CURSORES
      C_PIVOT     SYS_REFCURSOR;
      cnt         NUMBER;
    BEGIN

      SELECT COUNT(1) INTO cnt FROM user_tables WHERE table_name = 'tmp_pivot';
      IF cnt <> 0 THEN
        EXECUTE IMMEDIATE 'TRUNCATE TABLE tmp_pivot';
        EXECUTE IMMEDIATE 'DROP TABLE tmp_pivot';
      END IF;

      SELECT LISTAGG('''' || MES_REFERENCIA || ''' as "' || MES_REFERENCIA || '"', ',') WITHIN GROUP (ORDER BY MES_REFERENCIA) INTO   COLS
           FROM (SELECT DISTINCT MES_REFERENCIA FROM SOLICITACAO_CARGA_PRE_GFX WHERE mes_referencia BETWEEN P_MESREFINI AND P_MESREFFIM ORDER BY 1);

      v_query := 'SELECT * FROM ( SELECT ';
      CASE 
        WHEN P_CAMPO = 'VALOR' AND P_VISAO <> 'PIVOTAB' THEN
           v_query := v_query || 'MES_REFERENCIA, des_grupo_situacao, round(nvl(cast((SUM(case when nvl(VLR_RESUMO,0) > 0 then VLR_RESUMO else nvl(VLR_TCOF,0) end)/1000) AS NUMERIC(15,2)),0),0) Valor';
        WHEN P_CAMPO = 'VALOR' AND P_VISAO = 'PIVOTAB' THEN
           v_query := v_query || 'CSP, MES_REFERENCIA, des_grupo_situacao, round(nvl(cast((SUM(case when nvl(VLR_RESUMO,0) > 0 then VLR_RESUMO else nvl(VLR_TCOF,0) end)/1000) AS NUMERIC(15,2)),0),0) Valor';
        WHEN P_CAMPO = 'PCT' THEN
           v_query := v_query || 'CSP, MES_REFERENCIA, des_grupo_situacao, SUM(nvl(VLR_TCOF,0)) / CASE WHEN SUM(nvl(VLR_RESUMO,1)) <= 0 THEN 1 ELSE SUM(nvl(VLR_RESUMO,1)) END * 100 Valor';
        ELSE
           v_query := v_query || 'CSP, MES_REFERENCIA, ''Acionamentos'' des_grupo_situacao, SUM(QTD_ACIONAMENTOS) Valor';
      END CASE;

     --DES_GRUPO_SITUACAO AS "SITUAÇÃO", VALOR 
     V_QUERY := V_QUERY || '                FROM T_TOT_DASHBOARD_FISCAL WHERE TAB_TEMP = '''||P_TABELA_FATO||''' AND MES_REFERENCIA IS NOT NULL  GROUP BY CSP, MES_REFERENCIA, DES_GRUPO_SITUACAO) FATO ';
   
     IF P_VISAO = 'PIVOTAB' THEN
       V_QUERY := V_QUERY || 'PIVOT
       (  SUM(NVL(VALOR,0))
          FOR (MES_REFERENCIA) IN ( '|| COLS ||' )
       )';
     END IF;
   
     V_QUERY := V_QUERY || ' ORDER BY 1,2';

     dbms_output.put_line(V_QUERY);
     OPEN C_PIVOT FOR V_QUERY;

     P_FILTROS := C_PIVOT;
   END;

   PROCEDURE SP_SEL_SELECIONAR_BATIMENTO3(
      P_TABELA_FATO VARCHAR2,
      P_FILTROS OUT SYS_REFCURSOR )
    IS
      --VARIAVEIS DE TRABALHO
      cols        clob; --PEGA AS COLUNAS QUE SERAO GERADAS NO PIVOT (MES_REFERENCIA)
      V_MESREFINI CHAR(6);
      V_MESREFFIM CHAR(6);
      V_QUERY     CLOB;
      --VARIAVEIS DOS CURSORES
      C_PIVOT     SYS_REFCURSOR;
      cnt         NUMBER;
    BEGIN
      SELECT COUNT(1) INTO cnt FROM user_tables WHERE table_name = 'tmp_pivot';
      IF cnt <> 0 THEN
        EXECUTE IMMEDIATE 'TRUNCATE TABLE tmp_pivot';
        EXECUTE IMMEDIATE 'DROP TABLE tmp_pivot';
      END IF;

      SELECT min(mes_referencia), MAX(MES_REFERENCIA) INTO V_MESREFINI, V_MESREFFIM FROM T_TOT_DASHBOARD_FISCAL WHERE TAB_TEMP = P_TABELA_FATO;

      SELECT LISTAGG('''' || MES_REFERENCIA || ''' as "' || MES_REFERENCIA || '"', ',') WITHIN GROUP (ORDER BY MES_REFERENCIA) INTO   COLS
           FROM (SELECT DISTINCT MES_REFERENCIA FROM SOLICITACAO_CARGA_PRE_GFX WHERE mes_referencia BETWEEN V_MESREFINI AND V_MESREFFIM ORDER BY 1);

      V_QUERY := 'SELECT * FROM ( 
        SELECT MES_REFERENCIA, 
              CASE 
                WHEN UPPER(des_grupo_situacao) = ''REJEITADO'' THEN 4
                WHEN VLR_RESUMO = VLR_TCOF THEN 2
                ELSE 3
              END ORDEM,
              CASE 
                WHEN UPPER(des_grupo_situacao) = ''REJEITADO'' THEN ''FALTANTE''
                WHEN VLR_RESUMO = VLR_TCOF THEN ''PROC OK'' 
                ELSE ''PROC NOK''
              END SITUACAO,
              round(nvl(cast((SUM(case when nvl(VLR_RESUMO,0) > 0 then VLR_RESUMO else nvl(VLR_TCOF,0) end)/1000) AS NUMERIC(15,2)),0),0) Valor
        FROM T_TOT_DASHBOARD_FISCAL 
        WHERE MES_REFERENCIA IS NOT NULL  
              AND TAB_TEMP = ''' || P_TABELA_FATO || ''' 
        GROUP BY MES_REFERENCIA, 
              CASE 
                WHEN UPPER(des_grupo_situacao) = ''REJEITADO'' THEN 4
                WHEN VLR_RESUMO = VLR_TCOF THEN 2
                ELSE 3
              END,
              CASE 
                WHEN UPPER(des_grupo_situacao) = ''REJEITADO'' THEN ''FALTANTE''
                WHEN VLR_RESUMO = VLR_TCOF THEN ''PROC OK'' 
                ELSE ''PROC NOK''
              END ) FATO 
        PIVOT
        (  SUM(NVL(VALOR,0))
          FOR (MES_REFERENCIA) IN ( '|| COLS ||' )
        )
        UNION
        SELECT * FROM ( 
        SELECT MES_REFERENCIA, 1 ORDEM, UPPER(des_grupo_situacao) SITUACAO, round(nvl(cast((SUM(case when nvl(VLR_RESUMO,0) > 0 then VLR_RESUMO else nvl(VLR_TCOF,0) end)/1000) AS NUMERIC(15,2)),0),0) Valor
        FROM T_TOT_DASHBOARD_FISCAL 
        WHERE MES_REFERENCIA IS NOT NULL 
              AND UPPER(des_grupo_situacao) = ''RESUMO''
              AND TAB_TEMP = ''' || P_TABELA_FATO || ''' 
        GROUP BY MES_REFERENCIA, des_grupo_situacao) FATO 
        PIVOT
        (  SUM(NVL(VALOR,0))
          FOR (MES_REFERENCIA) IN ( '|| COLS ||' )
        )
      ORDER BY 1';

      OPEN C_PIVOT FOR V_QUERY;

      P_FILTROS := C_PIVOT;
    END;



   PROCEDURE SP_SEL_GRAFICO(
      P_TAB_FATO CHAR,
      P_GRAFICO_STR OUT CLOB )
    IS
      --VARIAVEIS DE TRABALHO
      V_SQL            clob;           -- VARIAVEL COMANDOS SQL EXECUTE IMMEDIATE
      V_MES            INTEGER;        -- MES CORRENTE
      V_ANO            INTEGER;        -- ANO CORRENTE
      C_DADOS          SYS_REFCURSOR;  -- CURSOR DE RETORNO COM DADOS DO GRAFICO
      V_DADOS_ANOMES   VARCHAR2(6);    -- VARIAVEL DO FETCH DO CURSOR C_DADOS
      V_DADOS_SITUACAO VARCHAR2(50);   -- VARIAVEL DO FETCH DO CURSOR C_DADOS
      V_DADOS_VALOR    VARCHAR2(6);    -- VARIAVEL DO FETCH DO CURSOR C_DADOS
      V_LINHA          CLOB;  -- LINHA DO GRAFICO
      V_ACHOU          INTEGER;        -- ACHOU DADOS REFERENTE AO ANOMES, SITUACAO
      V_MESREFINI      CHAR(6);
      V_MESREFFIM      CHAR(6);
    BEGIN

      --PASSA POR TODO PERIODO, MES A MES, ANO A ANO,
      --NÃO DEIXA NENHUM GRUPO VAZIO(ANO, MES, SITUACAO)
      SELECT min(mes_referencia), MAX(MES_REFERENCIA) INTO V_MESREFINI, V_MESREFFIM FROM T_TOT_DASHBOARD_FISCAL WHERE TAB_TEMP = P_TAB_FATO;
      V_MES := TO_NUMBER(SUBSTR(V_MESREFINI,5,2));
      V_ANO := TO_NUMBER(SUBSTR(V_MESREFINI,1,4));

      WHILE to_number(trim(TO_CHAR(V_ANO,'0000')) || trim(TO_CHAR(V_MES,'00'))) <= to_number(V_MESREFFIM)
      LOOP

        V_LINHA := '[''' || RTRIM(LTRIM(TO_CHAR(V_ANO,'0000'))) || RTRIM(LTRIM(TO_CHAR(V_MES, '00'))) || '''';

        OPEN C_DADOS FOR 
        SELECT MES_REFERENCIA, des_grupo_situacao, Valor FROM ( SELECT DSHA.MES_REFERENCIA, 
                               DSHA.des_grupo_situacao, 
--                               round(nvl(cast((SUM(nvl(DSHA.VLR_TCOF,1))/1000) AS NUMERIC(15,2)),0),0) Valor
                               CAST(((SUM(nvl(DSHA.VLR_TCOF,1)) / CASE WHEN AVG(VLR_TCOF_TOT)>0 THEN AVG(VLR_TCOF_TOT) ELSE 1 END) *100) AS NUMERIC(3,0)) Valor
                            FROM T_TOT_DASHBOARD_FISCAL DSHA
                            INNER JOIN (SELECT TAB_TEMP, MES_REFERENCIA, SUM(nvl(VLR_TCOF,0)) AS VLR_TCOF_TOT FROM T_TOT_DASHBOARD_FISCAL GROUP BY TAB_TEMP, MES_REFERENCIA) DSHB ON DSHB.TAB_TEMP=DSHA.TAB_TEMP AND DSHB.MES_REFERENCIA=DSHA.MES_REFERENCIA
                            WHERE DSHA.TAB_TEMP = P_TAB_FATO 
                                  AND DSHA.MES_REFERENCIA = trim(to_char(v_ano, '0000')) || trim(to_char(v_mes, '00'))
                            GROUP BY DSHA.MES_REFERENCIA, DSHA.DES_GRUPO_SITUACAO) FATO 
            ORDER BY 1,2;

        LOOP

          FETCH C_DADOS INTO V_DADOS_ANOMES, V_DADOS_SITUACAO, V_DADOS_VALOR;
          EXIT WHEN C_DADOS%NOTFOUND;
          V_ACHOU := 1;
          V_LINHA := V_lINHA || ',' || TO_CHAR(V_DADOS_VALOR) || ',''' || CASE WHEN V_DADOS_VALOR>0 THEN RTRIM(LTRIM(TO_CHAR(V_DADOS_VALOR,'999'))) ELSE '' END || '''';

        END LOOP; --C_DADOS

        P_GRAFICO_STR := P_GRAFICO_STR || V_LINHA || '],';
        V_MES := V_MES + 1;
        IF V_MES > 12 THEN
          V_MES := 1;
          V_ANO := V_ANO + 1;
        END IF;
      END LOOP; --ANOMES
      P_GRAFICO_STR := 'data.addColumn(''string'', ''Período'');
            data.addColumn(''number'', ''Aceito''); data.addColumn({ type: ''string'', role: ''annotation'' });
            data.addColumn(''number'', ''Pendente''); data.addColumn({ type: ''string'', role: ''annotation'' });
            data.addColumn(''number'', ''Recebido''); data.addColumn({ type: ''string'', role: ''annotation'' });
            data.addColumn(''number'', ''Rejeitado''); data.addColumn({ type: ''string'', role: ''annotation'' });
            data.addColumn(''number'', ''Resumo''); data.addColumn({ type: ''string'', role: ''annotation'' });
            data.addRows([' || P_GRAFICO_STR || ']);';
   END;

/*********************************GERENCIAL 2*****************************************************/
   PROCEDURE SP_SEL_GERENCIAL2( 
      P_CSP       CHAR := NULL,
      P_MESREF    CHAR := NULL,
      P_GR_SIT    VARCHAR2 := NULL,
      P_TAB_FATO  VARCHAR2,
      P_FILTROS   OUT SYS_REFCURSOR )
    IS
      V_FILTROS SYS_REFCURSOR;
    BEGIN
      OPEN V_FILTROS FOR 
          SELECT PIV.CSP, nvl(PIV.HOLDING, ' ') HOLDING, NVL(PIV.UF, '  ') UF, 
                 PIV.VLR_RESUMO, PIV.VLR_ACEITO, PIV.VLR_REJEITADO, PIV.VLR_RECEBIDO, PIV.VLR_PENDENTE,
                 ROUND(CASE WHEN NVL(VLR_TOTAL,0) = 0 THEN 0 ELSE (PIV.VLR_RESUMO    / VLR_TOTAL * 100) END, 2) AS PCT_RESUMO,
                 ROUND(CASE WHEN NVL(VLR_TOTAL,0) = 0 THEN 0 ELSE (PIV.VLR_ACEITO    / VLR_TOTAL * 100) END, 2) AS PCT_ACEITO,
                 ROUND(CASE WHEN NVL(VLR_TOTAL,0) = 0 THEN 0 ELSE (PIV.VLR_REJEITADO / VLR_TOTAL * 100) END, 2) AS PCT_REJEITADO,
                 ROUND(CASE WHEN NVL(VLR_TOTAL,0) = 0 THEN 0 ELSE (PIV.VLR_RECEBIDO  / VLR_TOTAL * 100) END, 2) AS PCT_RECEBIDO,
                 ROUND(CASE WHEN NVL(VLR_TOTAL,0) = 0 THEN 0 ELSE (PIV.VLR_PENDENTE  / VLR_TOTAL * 100) END, 2) AS PCT_PENDENTE
              FROM (
              SELECT *
                  FROM (
                        SELECT DSH.CSP, DSH.DES_HOLDING HOLDING, DSH.UF, nvl(DSH.DES_GRUPO_SITUACAO, 'VLR_TOTAL') AS DES_GRUPO_SITUACAO, SUM(DSH.VLR_TCOF) VLR_TCOF 
                            FROM T_TOT_DASHBOARD_FISCAL DSH
                            WHERE DSH.TAB_TEMP = P_TAB_FATO
                                  AND (DSH.CSP = P_CSP OR P_CSP IS NULL OR P_CSP = '0')
                                  AND (DSH.MES_REFERENCIA = P_MESREF OR P_MESREF IS NULL)
                                  AND (UPPER(DSH.DES_GRUPO_SITUACAO) = UPPER(P_GR_SIT) OR P_GR_SIT IS NULL OR P_GR_SIT = 'Todas')
                                  AND DSH.DES_HOLDING IS NOT NULL
                            GROUP BY cube(DSH.CSP, DSH.DES_HOLDING, DSH.UF, DSH.DES_GRUPO_SITUACAO)
                               HAVING (csp IS NOT NULL AND DES_HOLDING IS NOT NULL) OR (csp IS NOT NULL AND des_holding IS NULL AND uf IS NULL)
                       ) DET
              PIVOT (
                        SUM(DET.VLR_TCOF)
                        FOR (DES_GRUPO_SITUACAO) IN ( 'Resumo' AS "VLR_RESUMO", 'Aceito' AS "VLR_ACEITO", 'Rejeitado' AS "VLR_REJEITADO", 'Recebido' AS "VLR_RECEBIDO", 'Pendente' AS "VLR_PENDENTE", 'VLR_TOTAL' AS "VLR_TOTAL")
                    )
              ) PIV
              ORDER BY 1,2,3;
      P_FILTROS := V_FILTROS;
   END;

END PKG_DASHBOARD_FISCAL;

--select * from SYS.USER_ERRORS where NAME = 'PKG_DASHBOARD_FISCAL' --and type = 'PROCEDURE'
--TRUNCATE TABLE tmp_pivot;
--DROP TABLE tmp_pivot;
