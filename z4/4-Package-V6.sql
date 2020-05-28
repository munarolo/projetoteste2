SELECT * from SYS.USER_ERRORS where NAME = 'PKG_DASHBOARD_FISCAL' ;
/*
SELECT distinct tab_temp, mes_referencia FROM t_tot_dashboard_fiscal order by 1,2;
*/

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
      P_MESREF    VARCHAR2,
      P_TAB_FATO  VARCHAR2,
      P_FILTROS   OUT SYS_REFCURSOR )
    IS
      V_FILTROS SYS_REFCURSOR;
    BEGIN

    IF RTRIM(LTRIM(NVL(P_MESREF,'0'))) = '0' THEN
      OPEN V_FILTROS FOR 
           SELECT UF, SUM(nvl(QTD_ACIONAMENTOS,0)) QTD 
                   FROM T_TOT_DASHBOARD_FISCAL 
                   WHERE TAB_TEMP = P_TAB_FATO 
                         AND CSP = P_CSP 
                   GROUP BY UF HAVING SUM(nvl(QTD_ACIONAMENTOS,0)) > 0 ORDER BY UF;
    ELSE
      OPEN V_FILTROS FOR 
           SELECT UF, SUM(nvl(QTD_ACIONAMENTOS,0)) QTD 
                   FROM T_TOT_DASHBOARD_FISCAL 
                   WHERE TAB_TEMP = P_TAB_FATO 
                         AND CSP = P_CSP 
                         AND MES_REFERENCIA = P_MESREF
                   GROUP BY UF HAVING SUM(nvl(QTD_ACIONAMENTOS,0)) > 0 ORDER BY UF;
    END IF;

    P_FILTROS := V_FILTROS;
   END;

    PROCEDURE SP_SEL_GERENCIAL1_DETALHADO( 
      P_CSP       VARCHAR2,
      P_MESREF    VARCHAR2,
      P_GR_SIT    VARCHAR2,
      P_TAB_FATO  VARCHAR2,
      P_FILTROS   OUT SYS_REFCURSOR )
    IS
      V_FILTROS      SYS_REFCURSOR;
      V_QUERY        CLOB;
      V_QUERY_CSP    VARCHAR2(100);
      V_QUERY_MESREF VARCHAR2(100);
      V_QUERY_GR_SIT VARCHAR2(100);
    BEGIN

      IF RTRIM(LTRIM(NVL(P_CSP,'0'))) = '0' THEN 
         V_QUERY_CSP := ' OR 1=1)'; 
      ELSE 
         V_QUERY_CSP := ')'; 
      END IF;
    
      IF RTRIM(LTRIM(NVL(P_MESREF,'0'))) = '0' THEN 
        V_QUERY_MESREF := ' OR 1=1)'; 
      ELSE 
        V_QUERY_MESREF := ')'; 
      END IF;
      IF RTRIM(LTRIM(NVL(P_GR_SIT,'0'))) = '0' THEN 
        V_QUERY_GR_SIT := ' OR 1=1)'; 
      ELSE 
        V_QUERY_GR_SIT := ')'; 
      END IF;

      V_QUERY := '
           SELECT DSH.CSP, 
                  DSH.DES_HOLDING       AS OPERADORA, 
                  DSH.UF, 
                  DSH.MES_REFERENCIA, 
                  DSH.CICLO             AS CICLO_NF, 
                  RPAD('''',50,'' '')   AS NOME_ARQUIVO, 
                  DSH.DES_SITUACAO      AS SITUACAO_GRUPO, 
                  DSH.QTD_ACIONAMENTOS, 
                  DSH.VLR_RESUMO, 
                  DSH.VLR_TCOF
                FROM T_TOT_DASHBOARD_FISCAL DSH
                WHERE DSH.TAB_TEMP = ''' || P_TAB_FATO || '''' || 
                     ' AND (DSH.CSP = ''' || P_CSP || '''' || V_QUERY_CSP ||
                     ' AND (DSH.MES_REFERENCIA = ''' || P_MESREF || '''' || V_QUERY_MESREF ||
                     ' AND (UPPER(DSH.DES_GRUPO_SITUACAO) = ''' || UPPER(P_GR_SIT) || '''' || V_QUERY_GR_SIT ||
                     ' AND DSH.DES_HOLDING IS NOT NULL ';

      IF UPPER(P_GR_SIT) = 'RESUMO' THEN
         V_QUERY := V_QUERY || ' AND UPPER(DSH.DES_SITUACAO) = ''RESUMO'' ';
      ELSE
         V_QUERY := V_QUERY || ' AND UPPER(DSH.DES_SITUACAO) <> ''RESUMO'' ';
      END IF;

      V_QUERY := V_QUERY || ' ORDER BY 1';
             
      OPEN V_FILTROS FOR V_QUERY;

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
      V_QUERY   CLOB;
      V_QUERY_CSP    VARCHAR2(100);
      V_QUERY_MESREF VARCHAR2(100);
      V_QUERY_GR_SIT VARCHAR2(100);
    BEGIN

      IF RTRIM(LTRIM(NVL(P_CSP,'0'))) = '0' THEN 
         V_QUERY_CSP := ' OR 1=1)'; 
      ELSE 
         V_QUERY_CSP := ')'; 
      END IF;
    
      IF RTRIM(LTRIM(NVL(P_MESREF,'0'))) = '0' THEN 
        V_QUERY_MESREF := ' OR 1=1)'; 
      ELSE 
        V_QUERY_MESREF := ')'; 
      END IF;
      IF RTRIM(LTRIM(NVL(P_GR_SIT,'0'))) = '0' THEN 
        V_QUERY_GR_SIT := ' OR 1=1)'; 
      ELSE 
        V_QUERY_GR_SIT := ' OR UPPER(DSH.DES_GRUPO_SITUACAO)=''RESUMO'')'; 
      END IF;

      V_QUERY := '
          SELECT PIV.CSP, PIV.OPERADORA, PIV.ANO_MES_REF_NF, PIV.UF, PIV.CICLO,
                 PIV.VLR_RESUMO, PIV.VLR_ACEITO, PIV.VLR_REJEITADO, PIV.VLR_RECEBIDO, PIV.VLR_PENDENTE,
                 ROUND(CASE WHEN NVL(VLR_TOTAL,0) = 0 THEN 0 ELSE (PIV.VLR_ACEITO    / VLR_RESUMO * 100) END, 2) AS PCT_ACEITO,
                 ROUND(CASE WHEN NVL(VLR_TOTAL,0) = 0 THEN 0 ELSE (PIV.VLR_REJEITADO / VLR_RESUMO * 100) END, 2) AS PCT_REJEITADO,
                 ROUND(CASE WHEN NVL(VLR_TOTAL,0) = 0 THEN 0 ELSE (PIV.VLR_RECEBIDO  / VLR_RESUMO * 100) END, 2) AS PCT_RECEBIDO,
                 ROUND(CASE WHEN NVL(VLR_TOTAL,0) = 0 THEN 0 ELSE (PIV.VLR_PENDENTE  / VLR_RESUMO * 100) END, 2) AS PCT_PENDENTE
              FROM ( 
              SELECT *
                  FROM (
                        SELECT DSH.CSP, 
                               DSH.DES_HOLDING AS OPERADORA, 
                               DSH.UF,
                               DSH.MES_REFERENCIA AS ANO_MES_REF_NF, 
                               DSH.CICLO, 
                               UPPER(nvl(DSH.DES_GRUPO_SITUACAO, ''VLR_TOTAL'')) AS DES_GRUPO_SITUACAO,
                               SUM(DSH.VLR_RESUMO) VLR_RESUMO
                            FROM T_TOT_DASHBOARD_FISCAL DSH
                            WHERE DSH.TAB_TEMP = ''' || P_TAB_FATO || '''' ||
                                ' AND (DSH.CSP = ''' || P_CSP || '''' || V_QUERY_CSP ||
                                ' AND (DSH.MES_REFERENCIA = ''' || P_MESREF || '''' || V_QUERY_MESREF ||
                                ' AND (UPPER(DSH.DES_GRUPO_SITUACAO) = ''' || UPPER(P_GR_SIT) || '''' || V_QUERY_GR_SIT || 
                                ' AND DSH.DES_HOLDING IS NOT NULL ' || 
                                ' GROUP BY cube(DSH.CSP, DSH.MES_REFERENCIA, DSH.UF, DSH.DES_HOLDING, DSH.CICLO, DSH.DES_GRUPO_SITUACAO)
                               HAVING CSP IS NOT NULL AND DES_HOLDING IS NOT NULL AND MES_REFERENCIA IS NOT NULL AND UF IS NOT NULL AND CICLO IS NOT NULL
                       ) DET
              PIVOT (
                        SUM(DET.VLR_RESUMO)
                        FOR (DES_GRUPO_SITUACAO) IN ( ''RESUMO'' AS "VLR_RESUMO", ''ACEITO'' AS "VLR_ACEITO", ''REJEITADO'' AS "VLR_REJEITADO", ''RECEBIDO'' AS "VLR_RECEBIDO", ''PENDENTE'' AS "VLR_PENDENTE", ''VLR_TOTAL'' AS "VLR_TOTAL")
                    )
              ORDER BY 1,2,3,4
              ) PIV
              WHERE (NVL(PIV.VLR_ACEITO,0) + NVL(PIV.VLR_REJEITADO,0) + NVL(PIV.VLR_RECEBIDO,0) + NVL(PIV.VLR_PENDENTE,0)) > 0';

      OPEN V_FILTROS FOR V_QUERY;

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
      v_filtro_situacao := ' AND UPPER(DES_GRUPO_SITUACAO) = ''' || UPPER(P_SITUACAO) || '''';
    END IF;

    v_filtro_status := '';
    IF P_STATUS <> 'Todos' THEN
      IF P_STATUS = 'OK' THEN
        v_filtro_status :=  ' AND (NVL(vlr_resumo,0) <> NVL(vlr_tcof,0)) ';
      ELSE
        v_filtro_status :=  ' AND (NVL(vlr_resumo,0) = NVL(vlr_tcof,0)) ';
      END IF;
    END IF;

    v_filtro_ciclo := '';
    IF LENGTH(rtrim(ltrim(nvl(P_CICLOINI,'')))) > 0 THEN
      v_filtro_ciclo := ' AND CICLO BETWEEN  ' || P_CICLOINI || ' AND ' || P_CICLOFIM;
    END IF;

    SELECT COUNT(1) INTO cnt FROM user_tables WHERE table_name = 'tmp_pivot';
    IF cnt <> 0 THEN
      EXECUTE IMMEDIATE 'TRUNCATE TABLE tmp_pivot';
      EXECUTE IMMEDIATE 'DROP TABLE tmp_pivot';
    END IF;

    SELECT LISTAGG('''' || MES_REFERENCIA || ''' as "' || MES_REFERENCIA || '"', ',') WITHIN GROUP (ORDER BY MES_REFERENCIA) INTO   COLS
           FROM (SELECT DISTINCT MES_REFERENCIA FROM SOLICITACAO_CARGA_PRE_GFX WHERE mes_referencia BETWEEN P_MESREFINI AND P_MESREFFIM ORDER BY 1);

-- VOLTAR APÓS TESTES
-- VOLTAR APÓS TESTES
-- VOLTAR APÓS TESTES
-- VOLTAR APÓS TESTES
--    --APAGA FATOS ANTERIORES (15 MINUTOS PARA TRAZ)
    DELETE FROM T_TOT_DASHBOARD_FISCAL WHERE dat_inclusao < (SYSDATE-15/24/60) OR TAB_TEMP=V_TAB_DASH;
--    DELETE FROM T_TOT_DASHBOARD_FISCAL WHERE tab_temp <> 'TMP_DASHFI_14697_29_191620';
-- VOLTAR APÓS TESTES
-- VOLTAR APÓS TESTES
-- VOLTAR APÓS TESTES
-- VOLTAR APÓS TESTES
    
    v_query := 'SELECT ''' || V_TAB_DASH ||''' TAB_TEMP, ''%%'' as CSP,
       AF.SEQ_RECEPCAO,
       AF.DSN_RECEPCAO,
       GFX.COD_HOLDING, 
       GFX.DES_HOLDING,
       GFX.UF,
       GFX.MES_REFERENCIA,
       CASE
         WHEN AF.DSN_RECEPCAO IS NULL     THEN ''Pendente''
         WHEN AF.COD_CRITICA2 <> 0        THEN ''Rejeitado''
         WHEN AF.STATUS_CRITPROT = ''FJ'' THEN ''Rejeitado''
         WHEN AF.STATUS_CRITPROT IS NULL  THEN ''Recebido''
         WHEN AF.STATUS_CRITPROT = ''FR'' THEN ''Aceito''
         ELSE ''OUTROS''
       END AS DES_GRUPO_SITUACAO,
       CASE
         WHEN AF.DSN_RECEPCAO IS NULL     THEN 1
         WHEN AF.COD_CRITICA2 <> 0        THEN 2
         WHEN AF.STATUS_CRITPROT IS NULL  THEN 3
         WHEN AF.STATUS_CRITPROT = ''FR''   THEN 4
         WHEN AF.STATUS_CRITPROT = ''FJ''   THEN 5
         ELSE 9
       END AS COD_SITUACAO,
       CASE
         WHEN AF.DSN_RECEPCAO IS NULL     THEN ''TCOF Não Encontrado''
         WHEN AF.COD_CRITICA2 <> 0        THEN ''TCOF Criticado''
         WHEN AF.STATUS_CRITPROT = ''FJ'' THEN ''Mainframe Rejeitado''
         WHEN AF.STATUS_CRITPROT IS NULL  THEN ''Aguardando Protocolo''
         WHEN AF.STATUS_CRITPROT = ''FR'' THEN ''TCOF Recebido''
         ELSE ''OUTROS''
       END AS DES_SITUACAO,
       SUM(VLR_TOTAL_ARQ) VLR_TCOF,
       SUM(NVL(GFX.VLR_RESUMO,0)) VLR_RESUMO,
       (SELECT COUNT(1) FROM T_EMAIL_CONTROLEENVIO%%% E  WHERE AF.SEQ_RECEPCAO = E.ID_SEQ_RECEPCAO) + 
       (SELECT COUNT(1) FROM T_EMAIL_CONTROLEENVIO_HIST%%% HE WHERE AF.SEQ_RECEPCAO = HE.ID_SEQ_RECEPCAO) QTD_ACIONAMENTOS,
       SYSDATE AS DAT_INCLUSAO,
       GFX.CICLO
    FROM (SELECT SOL.COD_HOLDING, HC.DES_HOLDING, SOL.MES_REFERENCIA, DET.UF, DET.CICLO, SUM(VALOR_CONTABIL) VLR_RESUMO
       FROM SOLICITACAO_CARGA_PRE_GFX%%% SOL
         INNER JOIN T_SIGLA_HOLDING%%% HC ON HC.SIGLA_HOLDING = SOL.COD_HOLDING
         INNER JOIN RESUMO_FISCAL_GFX%%% DET ON SOL.ID_CARGA = DET.ID_CARGA AND SOL.TIPO_DEMONSTRATIVO = ''RESU''
         WHERE SOL.MES_REFERENCIA BETWEEN ''' || P_MESREFINI || ''' AND ''' || P_MESREFFIM || ''' ' || P_OPERADORA || ' ' || P_UF || v_filtro_ciclo ||
         ' GROUP BY SOL.COD_HOLDING, HC.DES_HOLDING, SOL.MES_REFERENCIA, DET.UF, DET.CICLO) GFX
    LEFT JOIN (SELECT * FROM T_CTRL_ARQ_FISCAIS%%% AF2
              INNER JOIN T_EMPRESA EMPCB ON EMPCB.COD_EOTEMP = AF2.COD_EOT_CB
              WHERE AF2.STATUS_RECEPCAO <> 5
                    AND AF2.COD_CRITICA = 0
                    AND TO_CHAR(AF2.DAT_EMISSAONF, ''YYYYMM'') BETWEEN '''||P_MESREFINI||''' AND '''||P_MESREFFIM||''' 
                    AND NVL(AF2.STATUS_CARGA, 0) = 0 
                    AND NVL(AF2.QTD_NOTA, 0) > 0 ' || v_filtro_situacao || ' ' || REPLACE(P_UF,'UF','COD_UFEMP') || ' ' || P_OPERADORA || ' ' || REPLACE(v_filtro_ciclo,'CICLO', 'CICLO_NF') ||'
                    /*
                    AND AF2.SEQ_RECEPCAO IN
                           (SELECT MAX(MAF.SEQ_RECEPCAO) SEQ_RECEPCAO
                              FROM T_CTRL_ARQ_FISCAIS%%% MAF
                              INNER JOIN T_EMPRESA MEMPCB ON MEMPCB.COD_EOTEMP = MAF.COD_EOT_CB AND MEMPCB.COD_UFEMP = EMPCB.COD_UFEMP
                           WHERE MAF.COD_CONTRATADA = AF2.COD_CONTRATADA
                                    AND MAF.DAT_EMISSAONF = AF2.DAT_EMISSAONF
                                    AND MAF.CICLO_NF = AF2.CICLO_NF
                                    AND MAF.STATUS_RECEPCAO <> 5)
                    */
                                    ) AF 
         ON AF.COD_CONTRATADA = GFX.COD_HOLDING
            AND TO_CHAR(AF.DAT_EMISSAONF, ''YYYYMM'') = GFX.MES_REFERENCIA
            AND AF.CICLO_NF = GFX.CICLO
            AND AF.COD_UFEMP = GFX.UF
    GROUP BY 
       AF.SEQ_RECEPCAO,
       AF.DSN_RECEPCAO,
       GFX.COD_HOLDING, 
       GFX.DES_HOLDING,
       GFX.UF,
       GFX.MES_REFERENCIA,
       CASE
         WHEN AF.DSN_RECEPCAO IS NULL     THEN ''Pendente''
         WHEN AF.COD_CRITICA2 <> 0        THEN ''Rejeitado''
         WHEN AF.STATUS_CRITPROT = ''FJ'' THEN ''Rejeitado''
         WHEN AF.STATUS_CRITPROT IS NULL  THEN ''Recebido''
         WHEN AF.STATUS_CRITPROT = ''FR'' THEN ''Aceito''
         ELSE ''OUTROS''
       END,
       CASE
         WHEN AF.DSN_RECEPCAO IS NULL     THEN 1
         WHEN AF.COD_CRITICA2 <> 0        THEN 2
         WHEN AF.STATUS_CRITPROT IS NULL  THEN 3
         WHEN AF.STATUS_CRITPROT = ''FR''   THEN 4
         WHEN AF.STATUS_CRITPROT = ''FJ''   THEN 5
         ELSE 9
       END,
       CASE
         WHEN AF.DSN_RECEPCAO IS NULL     THEN ''TCOF Não Encontrado''
         WHEN AF.COD_CRITICA2 <> 0        THEN ''TCOF Criticado''
         WHEN AF.STATUS_CRITPROT = ''FJ'' THEN ''Mainframe Rejeitado''
         WHEN AF.STATUS_CRITPROT IS NULL  THEN ''Aguardando Protocolo''
         WHEN AF.STATUS_CRITPROT = ''FR'' THEN ''TCOF Recebido''
         ELSE ''OUTROS''
       END,
       GFX.CICLO
union
SELECT ''' || V_TAB_DASH ||''' TAB_TEMP, ''%%'' as CSP,
       0 AS SEQ_RECEPCAO,
       '''' AS DSN_RECEPCAO,
       GFX.COD_HOLDING, 
       GFX.DES_HOLDING,
       GFX.UF,
       GFX.MES_REFERENCIA,
       ''Resumo'' AS DES_GRUPO_SITUACAO,
       0 AS COD_SITUACAO,
       ''Resumo'' AS DES_SITUACAO,
       0 VLR_TCOF,
       SUM(NVL(GFX.VLR_RESUMO,0)) VLR_RESUMO,
       0 QTD_ACIONAMENTOS,
       SYSDATE AS DAT_INCLUSAO,
       GFX.CICLO
    FROM (SELECT SOL.COD_HOLDING, HC.DES_HOLDING, SOL.MES_REFERENCIA, DET.UF, DET.CICLO, SUM(VALOR_CONTABIL) VLR_RESUMO
       FROM SOLICITACAO_CARGA_PRE_GFX%%% SOL
         INNER JOIN T_SIGLA_HOLDING%%% HC ON HC.SIGLA_HOLDING = SOL.COD_HOLDING
         INNER JOIN RESUMO_FISCAL_GFX%%% DET ON SOL.ID_CARGA = DET.ID_CARGA AND SOL.TIPO_DEMONSTRATIVO = ''RESU''
         WHERE SOL.MES_REFERENCIA BETWEEN ''' || P_MESREFINI || ''' AND ''' || P_MESREFFIM || ''' ' || P_OPERADORA || ' ' || P_UF || v_filtro_ciclo ||
         'GROUP BY SOL.COD_HOLDING, HC.DES_HOLDING, SOL.MES_REFERENCIA, DET.UF, DET.CICLO) GFX
    GROUP BY 
       GFX.COD_HOLDING, 
       GFX.DES_HOLDING,
       GFX.UF,
       GFX.MES_REFERENCIA,
       GFX.CICLO';

    V_CSP := P_CSP;
    IF P_CSP = '31' THEN v_querytot := replace(replace(v_query,'%%%',''),'%%','31'); END IF;
    IF P_CSP = '14' THEN v_querytot := replace(replace(v_query,'%%%','_BRT'),'%%','14'); END IF;
    IF P_CSP = '0' THEN v_querytot := replace(replace(v_query,'%%%','_BRT'),'%%','14') || ' union ' || replace(replace(v_query,'%%%',''),'%%','31'); V_CSP := '14';END IF;

    dbms_output.put_line( 'INSERT INTO T_TOT_DASHBOARD_FISCAL ' || v_querytot );
    EXECUTE IMMEDIATE 'INSERT INTO T_TOT_DASHBOARD_FISCAL ' || v_querytot;

    --DEIXA SOMENTE O ULTIMO REGISTRO VALIDO DE CADA TCOF
    v_query := 'DELETE FROM T_TOT_DASHBOARD_FISCAL TMP WHERE TAB_TEMP=''' || V_TAB_DASH || ''' AND DES_GRUPO_SITUACAO <> ''Resumo'' AND CSP=''14'' AND SEQ_RECEPCAO NOT IN 
                           (SELECT MAX(MAF.SEQ_RECEPCAO) SEQ_RECEPCAO
                              FROM T_CTRL_ARQ_FISCAIS_BRT MAF
                              INNER JOIN T_EMPRESA MEMPCB ON MEMPCB.COD_EOTEMP = MAF.COD_EOT_CB 
                           WHERE MAF.COD_CONTRATADA = tmp.COD_HOLDING
                                    AND TO_CHAR(MAF.DAT_EMISSAONF, ''YYYYMM'') = tmp.MES_REFERENCIA
                                    AND MAF.CICLO_NF = tmp.CICLO
                                    AND MAF.STATUS_RECEPCAO <> 5
                                    AND MEMPCB.COD_UFEMP = tmp.UF
                                    AND MAF.COD_CRITICA = 0
                                    AND NVL(MAF.STATUS_CARGA, 0) = 0 
                                    AND NVL(MAF.QTD_NOTA, 0) > 0 
                                    )';

    EXECUTE IMMEDIATE v_query;

    v_query := 'DELETE FROM T_TOT_DASHBOARD_FISCAL TMP WHERE TAB_TEMP=''' || V_TAB_DASH || ''' AND DES_GRUPO_SITUACAO <> ''Resumo'' AND CSP=''31'' AND SEQ_RECEPCAO NOT IN 
                           (SELECT MAX(MAF.SEQ_RECEPCAO) SEQ_RECEPCAO
                              FROM T_CTRL_ARQ_FISCAIS MAF
                              INNER JOIN T_EMPRESA MEMPCB ON MEMPCB.COD_EOTEMP = MAF.COD_EOT_CB 
                           WHERE MAF.COD_CONTRATADA = tmp.COD_HOLDING
                                    AND TO_CHAR(MAF.DAT_EMISSAONF, ''YYYYMM'') = tmp.MES_REFERENCIA
                                    AND MAF.CICLO_NF = tmp.CICLO
                                    AND MAF.STATUS_RECEPCAO <> 5
                                    AND MEMPCB.COD_UFEMP = tmp.UF
                                    AND MAF.COD_CRITICA = 0
                                    AND NVL(MAF.STATUS_CARGA, 0) = 0 
                                    AND NVL(MAF.QTD_NOTA, 0) > 0 
                                    )';

    EXECUTE IMMEDIATE v_query;


    --INSERINDO GRUPOS DE SITUACAO QUE NAO EXISTEM NA TABELA FATO (MES_REF A MES_REF E CSP A CSP)
    SELECT min(mes_referencia), MAX(MES_REFERENCIA) INTO V_MESREFINI, V_MESREFFIM FROM T_TOT_DASHBOARD_FISCAL WHERE TAB_TEMP = V_TAB_DASH;
    V_MES := TO_NUMBER(SUBSTR(V_MESREFINI,5,2));
    V_ANO := TO_NUMBER(SUBSTR(V_MESREFINI,1,4));
    
    WHILE to_number(trim(TO_CHAR(V_ANO,'0000')) || trim(TO_CHAR(V_MES,'00'))) <= to_number(V_MESREFFIM)
    LOOP

      INSERT INTO T_TOT_DASHBOARD_FISCAL (TAB_TEMP, CSP, mes_referencia, COD_SITUACAO, DES_GRUPO_SITUACAO, vlr_TCOF, VLR_RESUMO, QTD_ACIONAMENTOS, DAT_INCLUSAO) 
             SELECT V_TAB_DASH, V_CSP, trim(TO_CHAR(V_ANO))||trim(TO_CHAR(V_MES,'00')), TGR.COD_SITUACAO, tgr.DES_GRUPO_SITUACAO, 0, 0, 0, SYSDATE 
                FROM sch_dw_oi.t_grupo_situacao tgr WHERE NOT EXISTS (SELECT 1 FROM T_TOT_DASHBOARD_FISCAL fato 
                                                                             WHERE TAB_TEMP = V_TAB_DASH AND fato.csp= V_CSP AND fato.mes_referencia = trim(TO_CHAR(V_ANO))||trim(TO_CHAR(V_MES,'00')) AND fato.des_grupo_situacao=tgr.des_grupo_situacao);
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

   PROCEDURE SP_SEL_BATIMENTO1_GERATAB_V7(
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
      V_TAB_GFX VARCHAR2(100);
      V_TAB_TCO VARCHAR2(100);
    BEGIN
      
    --ALIAS DA TABELA FATO
    SELECT sps_NomeTabTemp('DASHFI') INTO V_TAB_DASH FROM DUAL;
    SELECT sps_NomeTabTemp('DASHFI1') INTO V_TAB_GFX FROM DUAL; --ALIAS DA TABELA RESUMO_FISCAL AGRUPADA E FILTRADA
    SELECT sps_NomeTabTemp('DASHFI2') INTO V_TAB_TCO FROM DUAL; --ALIAS DA TABELA TCOFs AGRUPADA E FILTRADA

    v_filtro_situacao := '';
    IF P_SITUACAO <> 'Todas' THEN
      v_filtro_situacao := ' AND UPPER(DES_GRUPO_SITUACAO) = ''' || UPPER(P_SITUACAO) || '''';
    END IF;

    v_filtro_status := '';
    IF P_STATUS <> 'Todos' THEN
      IF P_STATUS = 'OK' THEN
        v_filtro_status :=  ' AND (NVL(vlr_resumo,0) <> NVL(vlr_tcof,0)) ';
      ELSE
        v_filtro_status :=  ' AND (NVL(vlr_resumo,0) = NVL(vlr_tcof,0)) ';
      END IF;
    END IF;

    v_filtro_ciclo := '';
    IF LENGTH(rtrim(ltrim(nvl(P_CICLOINI,'')))) > 0 THEN
      v_filtro_ciclo := ' AND CICLO BETWEEN  ' || P_CICLOINI || ' AND ' || P_CICLOFIM;
    END IF;

    SELECT COUNT(1) INTO cnt FROM user_tables WHERE table_name = 'tmp_pivot';
    IF cnt <> 0 THEN
      EXECUTE IMMEDIATE 'TRUNCATE TABLE tmp_pivot';
      EXECUTE IMMEDIATE 'DROP TABLE tmp_pivot';
    END IF;

    SELECT COUNT(1) INTO cnt FROM user_tables WHERE table_name = V_TAB_GFX;
    IF cnt <> 0 THEN
      EXECUTE IMMEDIATE 'TRUNCATE TABLE ' || V_TAB_GFX ;
      EXECUTE IMMEDIATE 'DROP TABLE ' || V_TAB_GFX;
    END IF;

    SELECT COUNT(1) INTO cnt FROM user_tables WHERE table_name = V_TAB_tCO;
    IF cnt <> 0 THEN
      EXECUTE IMMEDIATE 'TRUNCATE TABLE ' || V_TAB_TCO ;
      EXECUTE IMMEDIATE 'DROP TABLE ' || V_TAB_TCO;
    END IF;

    --COLUNAS DE VALORES DO PIVOT
    SELECT LISTAGG('''' || MES_REFERENCIA || ''' as "' || MES_REFERENCIA || '"', ',') WITHIN GROUP (ORDER BY MES_REFERENCIA) INTO   COLS
           FROM (SELECT DISTINCT MES_REFERENCIA FROM SOLICITACAO_CARGA_PRE_GFX WHERE mes_referencia BETWEEN P_MESREFINI AND P_MESREFFIM ORDER BY 1);

-- VOLTAR APÓS TESTES
-- VOLTAR APÓS TESTES
-- VOLTAR APÓS TESTES
-- VOLTAR APÓS TESTES
--    --APAGA FATOS ANTERIORES (15 MINUTOS PARA TRAZ)
    DELETE FROM T_TOT_DASHBOARD_FISCAL WHERE dat_inclusao < (SYSDATE-15/24/60) OR TAB_TEMP=V_TAB_DASH;
--    DELETE FROM T_TOT_DASHBOARD_FISCAL WHERE tab_temp <> 'TMP_DASHFI_14697_29_191620';
-- VOLTAR APÓS TESTES
-- VOLTAR APÓS TESTES
-- VOLTAR APÓS TESTES
-- VOLTAR APÓS TESTES
    
/* AQUI INI*/
    v_query := 'SELECT ''%%'' as CSP, 
                       SOL.COD_HOLDING, 
                       HC.DES_HOLDING, 
                       SOL.MES_REFERENCIA, 
                       DET.UF, 
                       SUM(VALOR_CONTABIL) VLR_RESUMO
       FROM SOLICITACAO_CARGA_PRE_GFX%%% SOL
         INNER JOIN T_SIGLA_HOLDING%%% HC ON HC.SIGLA_HOLDING = SOL.COD_HOLDING
         INNER JOIN RESUMO_FISCAL_GFX%%% DET ON SOL.ID_CARGA = DET.ID_CARGA AND SOL.TIPO_DEMONSTRATIVO = ''RESU''
         WHERE SOL.MES_REFERENCIA BETWEEN ''' || P_MESREFINI || ''' AND ''' || P_MESREFFIM || ''' ' || P_OPERADORA || ' ' || P_UF || 
       ' GROUP BY SOL.COD_HOLDING, 
                HC.DES_HOLDING, 
                SOL.MES_REFERENCIA, 
                DET.UF ';

    V_CSP := P_CSP;
    IF P_CSP = '31' THEN v_querytot := replace(replace(v_query,'%%%',''),'%%','31'); END IF;
    IF P_CSP = '14' THEN v_querytot := replace(replace(v_query,'%%%','_BRT'),'%%','14'); END IF;
    IF P_CSP = '0' THEN v_querytot := replace(replace(v_query,'%%%','_BRT'),'%%','14') || ' union ' || replace(replace(v_query,'%%%',''),'%%','31'); V_CSP := '14';END IF;

    EXECUTE IMMEDIATE 'CREATE GLOBAL TEMPORARY TABLE  '|| V_TAB_GFX ||' ON COMMIT PRESERVE ROWS AS ' || v_querytot;

DBMS_OUTPUT.PUT_LINE('CREATE GLOBAL TEMPORARY TABLE  '|| V_TAB_GFX ||' ON COMMIT PRESERVE ROWS AS ' || v_querytot);
    
    V_QUERY := 'SELECT ''%%'' as CSP, 
                       TO_CHAR(AF2.DAT_EMISSAONF, ''YYYYMM'') AS MES_REFERENCIA,
                       AF2.COD_CONTRATADA , 
                       EMPCB.COD_UFEMP AS UF,
                       CASE
                         WHEN AF2.DSN_RECEPCAO IS NULL       THEN ''Pendente''
                         WHEN AF2.COD_CRITICA2 <> 0          THEN ''Rejeitado''
                         WHEN AF2.STATUS_CRITPROT = ''FJ''   THEN ''Rejeitado''
                         WHEN AF2.STATUS_CRITPROT IS NULL    THEN ''Recebido''
                         WHEN AF2.STATUS_CRITPROT = ''FR''   THEN ''Aceito''
                         ELSE ''OUTROS''
                       END AS DES_GRUPO_SITUACAO,
                       CASE
                         WHEN AF2.DSN_RECEPCAO IS NULL       THEN 1
                         WHEN AF2.COD_CRITICA2 <> 0          THEN 2
                         WHEN AF2.STATUS_CRITPROT IS NULL    THEN 3
                         WHEN AF2.STATUS_CRITPROT = ''FR''   THEN 4
                         WHEN AF2.STATUS_CRITPROT = ''FJ''   THEN 5
                         ELSE 9
                       END COD_SITUACAO,
                       '' '' AS DES_SITUACAO,
                       SUM(AF2.VLR_TOTAL_ARQ) AS VLR_TCOF 
       FROM T_CTRL_ARQ_FISCAIS%%% AF2 
              INNER JOIN T_EMPRESA EMPCB ON EMPCB.COD_EOTEMP = AF2.COD_EOT_CB
              WHERE AF2.STATUS_RECEPCAO <> 5
                    AND AF2.COD_CRITICA = 0
                    AND AF2.COD_CRITICA2 = 0
                    AND TO_CHAR(AF2.DAT_EMISSAONF, ''YYYYMM'') BETWEEN '''||P_MESREFINI||''' AND '''||P_MESREFFIM||''' 
                    AND NVL(AF2.STATUS_CARGA, 0) = 0 
                    AND NVL(AF2.QTD_NOTA, 0) > 0 ' || v_filtro_situacao || ' ' || REPLACE(P_UF,'UF','COD_UFEMP') || ' ' || P_OPERADORA || ' 
       GROUP BY AF2.COD_CONTRATADA, TO_CHAR(AF2.DAT_EMISSAONF, ''YYYYMM''), EMPCB.COD_UFEMP,
                 CASE 
                   WHEN AF2.DSN_RECEPCAO IS NULL     THEN ''Pendente''
                   WHEN AF2.COD_CRITICA2 <> 0        THEN ''Rejeitado''
                   WHEN AF2.STATUS_CRITPROT = ''FJ'' THEN ''Rejeitado''
                   WHEN AF2.STATUS_CRITPROT IS NULL  THEN ''Recebido''
                   WHEN AF2.STATUS_CRITPROT = ''FR'' THEN ''Aceito''
                   ELSE ''OUTROS''
                 END, 
                 CASE
                   WHEN AF2.DSN_RECEPCAO IS NULL       THEN 1
                   WHEN AF2.COD_CRITICA2 <> 0          THEN 2
                   WHEN AF2.STATUS_CRITPROT IS NULL    THEN 3
                   WHEN AF2.STATUS_CRITPROT = ''FR''   THEN 4
                   WHEN AF2.STATUS_CRITPROT = ''FJ''   THEN 5
                   ELSE 9
                 END ';
 
    IF P_CSP = '31' THEN v_querytot := replace(replace(v_query,'%%%',''),'%%','31'); END IF;
    IF P_CSP = '14' THEN v_querytot := replace(replace(v_query,'%%%','_BRT'),'%%','14'); END IF;
    IF P_CSP = '0' THEN v_querytot := replace(replace(v_query,'%%%','_BRT'),'%%','14') || ' union ' || replace(replace(v_query,'%%%',''),'%%','31'); V_CSP := '14';END IF;

    EXECUTE IMMEDIATE 'CREATE GLOBAL TEMPORARY TABLE  '|| V_TAB_TCO ||' ON COMMIT PRESERVE ROWS AS ' || v_querytot;

DBMS_OUTPUT.PUT_LINE('CREATE GLOBAL TEMPORARY TABLE  '|| V_TAB_TCO ||' ON COMMIT PRESERVE ROWS AS ' || v_querytot);

    v_querytot := '    
    SELECT ''' || V_TAB_DASH || ''' AS TAB_TEMP, 
           GFX.CSP,
           0 AS SEQ_RECEPCAO,
           '''' AS DSN_RECEPCAO,
           GFX.COD_HOLDING, 
           GFX.DES_HOLDING,
           GFX.UF,
           GFX.MES_REFERENCIA,
           NVL(GR.DES_GRUPO_SITUACAO,'''') AS DES_GRUPO_SITUACAO, 
           NVL(TCO.COD_SITUACAO,0) COD_SITUACAO,
           '''' AS DES_SITUACAO,
           VLR_TCOF,
           GFX.VLR_RESUMO,
           0 AS QTD_ACIONAMENTOS,
           /*(SELECT COUNT(1) FROM T_EMAIL_CONTROLEENVIO%%% E  WHERE AF.SEQ_RECEPCAO = E.ID_SEQ_RECEPCAO) + 
           (SELECT COUNT(1) FROM T_EMAIL_CONTROLEENVIO_HIST%%% HE WHERE AF.SEQ_RECEPCAO = HE.ID_SEQ_RECEPCAO) QTD_ACIONAMENTOS,*/
           SYSDATE AS DAT_INCLUSAO,
           0 AS CICLO
           FROM ' || V_TAB_GFX || ' GFX
           LEFT JOIN ' || V_TAB_TCO || ' TCO ON GFX.CSP=TCO.CSP AND GFX.COD_HOLDING=TCO.COD_CONTRATADA AND GFX.MES_REFERENCIA=TCO.MES_REFERENCIA AND GFX.UF=TCO.UF
           LEFT JOIN SCH_DW_OI.T_GRUPO_SITUACAO GR ON GR.COD_SITUACAO = TCO.COD_SITUACAO
    UNION
    SELECT ''' || V_TAB_DASH || ''' AS  TAB_TEMP, 
           GFX.CSP,
           0 AS SEQ_RECEPCAO,
           '''' AS DSN_RECEPCAO,
           GFX.COD_HOLDING, 
           GFX.DES_HOLDING,
           GFX.UF,
           GFX.MES_REFERENCIA,
           ''Resumo'' AS DES_GRUPO_SITUACAO, 
           0 COD_SITUACAO,
           ''Resumo'' AS DES_SITUACAO,
           0 AS VLR_TCOF,
           VLR_RESUMO,
           0 AS QTD_ACIONAMENTOS,
           /*(SELECT COUNT(1) FROM T_EMAIL_CONTROLEENVIO%%% E  WHERE AF.SEQ_RECEPCAO = E.ID_SEQ_RECEPCAO) + 
           (SELECT COUNT(1) FROM T_EMAIL_CONTROLEENVIO_HIST%%% HE WHERE AF.SEQ_RECEPCAO = HE.ID_SEQ_RECEPCAO) QTD_ACIONAMENTOS,*/
           SYSDATE AS DAT_INCLUSAO,
           0 AS CICLO
           FROM ' || V_TAB_GFX || ' GFX';
/* AQUI FIM */


    dbms_output.put_line( 'INSERT INTO T_TOT_DASHBOARD_FISCAL ' || v_querytot );
    EXECUTE IMMEDIATE 'INSERT INTO T_TOT_DASHBOARD_FISCAL ' || v_querytot;

    --DEIXA SOMENTE O ULTIMO REGISTRO VALIDO DE CADA TCOF
    v_query := 'DELETE FROM T_TOT_DASHBOARD_FISCAL TMP WHERE TAB_TEMP=''' || V_TAB_DASH || ''' AND DES_GRUPO_SITUACAO <> ''Resumo'' AND CSP=''14'' AND SEQ_RECEPCAO NOT IN 
                           (SELECT MAX(MAF.SEQ_RECEPCAO) SEQ_RECEPCAO
                              FROM T_CTRL_ARQ_FISCAIS_BRT MAF
                              INNER JOIN T_EMPRESA MEMPCB ON MEMPCB.COD_EOTEMP = MAF.COD_EOT_CB 
                           WHERE MAF.COD_CONTRATADA = tmp.COD_HOLDING
                                    AND TO_CHAR(MAF.DAT_EMISSAONF, ''YYYYMM'') = tmp.MES_REFERENCIA
                                    AND MAF.CICLO_NF = tmp.CICLO
                                    AND MAF.STATUS_RECEPCAO <> 5
                                    AND MEMPCB.COD_UFEMP = tmp.UF
                                    AND MAF.COD_CRITICA = 0
                                    AND NVL(MAF.STATUS_CARGA, 0) = 0 
                                    AND NVL(MAF.QTD_NOTA, 0) > 0 
                                    )';

    --EXECUTE IMMEDIATE v_query;

    v_query := 'DELETE FROM T_TOT_DASHBOARD_FISCAL TMP WHERE TAB_TEMP=''' || V_TAB_DASH || ''' AND DES_GRUPO_SITUACAO <> ''Resumo'' AND CSP=''31'' AND SEQ_RECEPCAO NOT IN 
                           (SELECT MAX(MAF.SEQ_RECEPCAO) SEQ_RECEPCAO
                              FROM T_CTRL_ARQ_FISCAIS MAF
                              INNER JOIN T_EMPRESA MEMPCB ON MEMPCB.COD_EOTEMP = MAF.COD_EOT_CB 
                           WHERE MAF.COD_CONTRATADA = tmp.COD_HOLDING
                                    AND TO_CHAR(MAF.DAT_EMISSAONF, ''YYYYMM'') = tmp.MES_REFERENCIA
                                    AND MAF.CICLO_NF = tmp.CICLO
                                    AND MAF.STATUS_RECEPCAO <> 5
                                    AND MEMPCB.COD_UFEMP = tmp.UF
                                    AND MAF.COD_CRITICA = 0
                                    AND NVL(MAF.STATUS_CARGA, 0) = 0 
                                    AND NVL(MAF.QTD_NOTA, 0) > 0 
                                    )';

    --EXECUTE IMMEDIATE v_query;

    --EXLUI TEMPORARIAS
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ' || V_TAB_GFX;
    EXECUTE IMMEDIATE 'DROP TABLE ' || V_TAB_GFX;
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ' || V_TAB_TCO;
    EXECUTE IMMEDIATE 'DROP TABLE ' || V_TAB_TCO;


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


   PROCEDURE SP_SEL_BATIMENTO1_GERATAB_TCOF(
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
      v_filtro_situacao := ' AND UPPER(DES_GRUPO_SITUACAO) = ''' || UPPER(P_SITUACAO) || '''';
    END IF;

    v_filtro_status := '';
    IF P_STATUS <> 'Todos' THEN
      IF P_STATUS = 'OK' THEN
        v_filtro_status :=  ' AND (NVL(vlr_resumo,0) <> NVL(vlr_tcof,0)) ';
      ELSE
        v_filtro_status :=  ' AND (NVL(vlr_resumo,0) = NVL(vlr_tcof,0)) ';
      END IF;
    END IF;

    v_filtro_ciclo := '';
    IF LENGTH(rtrim(ltrim(nvl(P_CICLOINI,'')))) > 0 THEN
      v_filtro_ciclo := ' AND CICLO_NF BETWEEN  ' || P_CICLOINI || ' AND ' || P_CICLOFIM;
    END IF;

    SELECT COUNT(1) INTO cnt FROM user_tables WHERE table_name = 'tmp_pivot';
    IF cnt <> 0 THEN
      EXECUTE IMMEDIATE 'TRUNCATE TABLE tmp_pivot';
      EXECUTE IMMEDIATE 'DROP TABLE tmp_pivot';
    END IF;

    SELECT LISTAGG('''' || MES_REFERENCIA || ''' as "' || MES_REFERENCIA || '"', ',') WITHIN GROUP (ORDER BY MES_REFERENCIA) INTO   COLS
           FROM (SELECT DISTINCT MES_REFERENCIA FROM SOLICITACAO_CARGA_PRE_GFX WHERE mes_referencia BETWEEN P_MESREFINI AND P_MESREFFIM ORDER BY 1);

-- VOLTAR APÓS TESTES
-- VOLTAR APÓS TESTES
-- VOLTAR APÓS TESTES
-- VOLTAR APÓS TESTES
--    --APAGA FATOS ANTERIORES (15 MINUTOS PARA TRAZ)
    DELETE FROM T_TOT_DASHBOARD_FISCAL WHERE dat_inclusao < (SYSDATE-15/24/60) OR TAB_TEMP=V_TAB_DASH;
--    DELETE FROM T_TOT_DASHBOARD_FISCAL WHERE dat_inclusao < (SYSDATE-15/24/60) AND TAB_TEMP <> 'TMP_DASHFI_14673_13_155817';
--    P_TAB_FATO := 'TMP_DASHFI_14673_13_155817';
--    RETURN;
-- VOLTAR APÓS TESTES
-- VOLTAR APÓS TESTES
-- VOLTAR APÓS TESTES
-- VOLTAR APÓS TESTES
    

    v_query := 'SELECT ''' || V_TAB_DASH ||''' TAB_TEMP, ''%%'' as CSP,
       AF.SEQ_RECEPCAO,
       AF.DSN_RECEPCAO,
       HC.SIGLA_HOLDING COD_HOLDING, 
       HC.DES_HOLDING,
       EMPCB.COD_UFEMP UF,
       TO_CHAR(AF.DAT_EMISSAONF, ''YYYYMM'') MES_REFERENCIA,
       NVL(DES_GRUPO_SITUACAO,''OUTROS'') DES_GRUPO_SITUACAO,
       CASE
         WHEN AF.DSN_RECEPCAO IS NULL     THEN 1
         WHEN AF.COD_CRITICA2 <> 0        THEN 2
         WHEN AF.STATUS_CRITPROT IS NULL  THEN 3
         WHEN AF.STATUS_CRITPROT = ''FR''   THEN 4
         WHEN AF.STATUS_CRITPROT = ''FJ''   THEN 5
         ELSE 9
       END COD_SITUACAO,
       CASE
         WHEN AF.DSN_RECEPCAO IS NULL     THEN ''TCOF Não Encontrado''
         WHEN AF.COD_CRITICA2 <> 0        THEN ''TCOF Criticado''
         WHEN AF.STATUS_CRITPROT IS NULL  THEN ''Aguardando Protocolo''
         WHEN AF.STATUS_CRITPROT = ''FR''   THEN ''TCOF Recebido''
         WHEN AF.STATUS_CRITPROT = ''FJ''   THEN ''Mainframe Rejeitado''
         ELSE ''OUTROS''
       END DES_SITUACAO,
       SUM(VLR_TOTAL_ARQ) VLR_TCOF,
       SUM(NVL(GFX.VLR_RESUMO,0)) VLR_RESUMO,
       (SELECT COUNT(1) FROM T_EMAIL_CONTROLEENVIO%%% E  WHERE AF.SEQ_RECEPCAO = E.ID_SEQ_RECEPCAO) + 
       (SELECT COUNT(1) FROM T_EMAIL_CONTROLEENVIO_HIST%%% HE WHERE AF.SEQ_RECEPCAO = HE.ID_SEQ_RECEPCAO) QTD_ACIONAMENTOS,
       SYSDATE AS DAT_INCLUSAO,
       AF.CICLO_NF CICLO
    FROM T_CTRL_ARQ_FISCAIS%%% af
    INNER JOIN T_EMPRESA EMPCB ON AF.COD_EOT_CB = EMPCB.COD_EOTEMP
    INNER JOIN T_SIGLA_HOLDING%%% HC ON EMPCB.SIGLA_HOLDING = HC.SIGLA_HOLDING
    LEFT JOIN SCH_DW_OI.T_GRUPO_SITUACAO TGR ON TGR.COD_SITUACAO = CASE
                                                                     WHEN AF.DSN_RECEPCAO IS NULL     THEN 1
                                                                     WHEN AF.COD_CRITICA2 <> 0        THEN 2
                                                                     WHEN AF.STATUS_CRITPROT IS NULL  THEN 3
                                                                     WHEN AF.STATUS_CRITPROT = ''FR''   THEN 4
                                                                     WHEN AF.STATUS_CRITPROT = ''FJ''   THEN 5
                                                                     ELSE 9
                                                                   END 
    LEFT JOIN (SELECT SOL.COD_HOLDING, SOL.MES_REFERENCIA, DET.UF, DET.CICLO, SUM(VALOR_CONTABIL) VLR_RESUMO
       FROM SOLICITACAO_CARGA_PRE_GFX%%% SOL
         INNER JOIN T_SIGLA_HOLDING%%% HC    ON SOL.COD_HOLDING = HC.SIGLA_HOLDING
         INNER JOIN RESUMO_FISCAL_GFX%%% DET ON SOL.ID_CARGA = DET.ID_CARGA AND SOL.TIPO_DEMONSTRATIVO = ''RESU''
         GROUP BY SOL.COD_HOLDING, SOL.MES_REFERENCIA, DET.UF, DET.CICLO) GFX
         ON GFX.COD_HOLDING = HC.SIGLA_HOLDING 
            AND GFX.MES_REFERENCIA = TO_CHAR(AF.DAT_EMISSAONF, ''YYYYMM'') 
            AND GFX.UF = EMPCB.COD_UFEMP
            AND GFX.CICLO = AF.CICLO_NF
    WHERE AF.STATUS_RECEPCAO <> 5
          AND AF.COD_CRITICA = 0
          AND TO_CHAR(AF.DAT_EMISSAONF, ''YYYYMM'') BETWEEN '''||P_MESREFINI||''' AND '''||P_MESREFFIM||'''
          AND NVL(AF.STATUS_CARGA, 0) = 0 
          AND NVL(AF.QTD_NOTA, 0) > 0 ' || v_filtro_situacao || ' ' || P_UF || ' ' || P_OPERADORA || ' ' || v_filtro_ciclo ||'
    GROUP BY 
       AF.SEQ_RECEPCAO,
       AF.DSN_RECEPCAO,
       HC.SIGLA_HOLDING, 
       HC.DES_HOLDING,
       EMPCB.COD_UFEMP,
       TO_CHAR(AF.DAT_EMISSAONF, ''YYYYMM''),
       NVL(DES_GRUPO_SITUACAO,''OUTROS''),
       CASE
         WHEN AF.DSN_RECEPCAO IS NULL     THEN 1
         WHEN AF.COD_CRITICA2 <> 0        THEN 2
         WHEN AF.STATUS_CRITPROT IS NULL  THEN 3
         WHEN AF.STATUS_CRITPROT = ''FR''   THEN 4
         WHEN AF.STATUS_CRITPROT = ''FJ''   THEN 5
         ELSE 9
       END,
       CASE
         WHEN AF.DSN_RECEPCAO IS NULL     THEN ''TCOF Não Encontrado''
         WHEN AF.COD_CRITICA2 <> 0        THEN ''TCOF Criticado''
         WHEN AF.STATUS_CRITPROT IS NULL  THEN ''Aguardando Protocolo''
         WHEN AF.STATUS_CRITPROT = ''FR''   THEN ''TCOF Recebido''
         WHEN AF.STATUS_CRITPROT = ''FJ''   THEN ''Mainframe Rejeitado''
         ELSE ''OUTROS''
       END,
       AF.CICLO_NF';

    V_CSP := P_CSP;
    IF P_CSP = '31' THEN v_querytot := replace(replace(v_query,'%%%',''),'%%','31'); END IF;
    IF P_CSP = '14' THEN v_querytot := replace(replace(v_query,'%%%','_BRT'),'%%','14'); END IF;
    IF P_CSP = '0' THEN v_querytot := replace(replace(v_query,'%%%','_BRT'),'%%','14') || ' union ' || replace(replace(v_query,'%%%',''),'%%','31'); V_CSP := '14';END IF;

    dbms_output.put_line( 'INSERT INTO T_TOT_DASHBOARD_FISCAL ' || v_querytot );
    EXECUTE IMMEDIATE 'INSERT INTO T_TOT_DASHBOARD_FISCAL ' || v_querytot;

    --SELECT * FROM HOUVER DUPLICIDADES, APAGA OUTRAS E DEIXA A OK
    v_query := 'DELETE FROM T_TOT_DASHBOARD_FISCAL TMP WHERE TAB_TEMP=''' || V_TAB_DASH || ''' AND TMP.COD_SITUACAO <= 2 AND EXISTS (SELECT 1 FROM T_TOT_DASHBOARD_FISCAL TMP2 WHERE TMP2.TAB_TEMP=TMP.TAB_TEMP AND TMP2.COD_HOLDING=TMP.COD_HOLDING AND TMP2.CICLO=TMP2.CICLO AND TMP2.MES_REFERENCIA=TMP.MES_REFERENCIA AND TMP2.UF=TMP.UF AND TMP2.COD_SITUACAO >2)';
    EXECUTE IMMEDIATE v_query;

    IF P_STATUS <> 'Todos' THEN
      v_query := 'DELETE FROM T_TOT_DASHBOARD_FISCAL WHERE TAB_TEMP =''' || V_TAB_DASH || ''' ' || v_filtro_status;
      EXECUTE IMMEDIATE v_query;
    END IF;

    v_query := 'UPDATE T_TOT_DASHBOARD_FISCAL SET des_grupo_situacao = ''Resumo'', COD_SITUACAO=0 , DES_SITUACAO = ''Resumo'' WHERE VLR_RESUMO > 0 AND TAB_TEMP =''' || V_TAB_DASH || '''';
    EXECUTE IMMEDIATE v_query;

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

      CASE 
        WHEN P_CAMPO = 'VALOR' AND P_VISAO <> 'PIVOTAB' THEN
           v_query := v_query || 'SELECT * FROM ( SELECT AF.MES_REFERENCIA, AF.DES_GRUPO_SITUACAO, CAST((SUM(AF.VLR_RESUMO)/1000) AS NUMERIC(15,2)) VALOR, GR.ORDEM';
        WHEN P_CAMPO = 'VALOR' AND P_VISAO = 'PIVOTAB' THEN
           v_query := v_query || 'SELECT * FROM ( SELECT AF.CSP, AF.MES_REFERENCIA, AF.DES_GRUPO_SITUACAO, CAST((SUM(AF.VLR_RESUMO)/1000) AS NUMERIC(15,2)) VALOR, GR.ORDEM';
        WHEN P_CAMPO = 'PCT' THEN
           v_query := v_query || 'SELECT * FROM ( SELECT AF.CSP, AF.MES_REFERENCIA, AF.DES_GRUPO_SITUACAO, (SUM(NVL(AF.VLR_TCOF,0)) / SUM(NVL(AF.VLR_RESUMO,1)) * 100) VALOR, GR.ORDEM';
        ELSE
           v_query := v_query || 'SELECT * FROM ( SELECT AF.CSP, AF.MES_REFERENCIA, ''ACIONAMENTOS'' DES_GRUPO_SITUACAO, SUM(AF.QTD_ACIONAMENTOS) VALOR, 1 AS ORDEM';
      END CASE;

     --DES_GRUPO_SITUACAO AS "SITUAÇÃO", VALOR 
     V_QUERY := V_QUERY || ' FROM T_TOT_DASHBOARD_FISCAL AF ';
     V_QUERY := V_QUERY || ' INNER JOIN SCH_DW_OI.T_GRUPO_SITUACAO GR ON GR.COD_SITUACAO = AF.COD_SITUACAO ';
     V_QUERY := V_QUERY || ' WHERE AF.TAB_TEMP = '''||P_TABELA_FATO||''' AND AF.MES_REFERENCIA IS NOT NULL ';
     V_QUERY := V_QUERY || ' GROUP BY AF.CSP, AF.MES_REFERENCIA, AF.DES_GRUPO_SITUACAO, GR.ORDEM ';
     V_QUERY := V_QUERY || ' ORDER BY AF.CSP, GR.ORDEM) FATO ';
   
     IF P_VISAO = 'PIVOTAB' THEN
       V_QUERY := V_QUERY || 'PIVOT
       (  SUM(NVL(VALOR,0))
          FOR (MES_REFERENCIA) IN ( '|| COLS ||' )
       )';
     END IF;
     V_QUERY := V_QUERY || ' ORDER BY 1, ORDEM';
   
   
/*
   SELECT * FROM ( 
       SELECT AF.CSP, AF.MES_REFERENCIA, AF.des_grupo_situacao, round(nvl(cast((SUM(AF.VLR_RESUMO)/1000) AS NUMERIC(15,2)),0),0) Valor, GR.ORDEM
              FROM T_TOT_DASHBOARD_FISCAL af
              INNER JOIN SCH_DW_OI.T_GRUPO_SITUACAO GR ON GR.COD_SITUACAO = AF.COD_SITUACAO
              WHERE AF.TAB_TEMP = 'TMP_DASHFI_14676_17_120614' 
                    AND AF.MES_REFERENCIA IS NOT NULL  
              GROUP BY AF.CSP, AF.MES_REFERENCIA, AF.DES_GRUPO_SITUACAO , GR.ORDEM
              ORDER BY AF.CSP, GR.ORDEM
              ) FATO PIVOT
       (  SUM(NVL(VALOR,0))
          FOR (MES_REFERENCIA) IN ( '201912' as "201912",'202001' as "202001",'202002' as "202002" )
       ) ORDER BY CSP, ORDEM;
*/

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
              round(nvl(cast((SUM(VLR_RESUMO)/1000) AS NUMERIC(15,2)),0),0) Valor
        FROM T_TOT_DASHBOARD_FISCAL 
        WHERE MES_REFERENCIA IS NOT NULL  
              AND TAB_TEMP = ''' || P_TABELA_FATO || ''' AND UPPER(DES_GRUPO_SITUACAO) <> ''RESUMO'' 
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
        SELECT MES_REFERENCIA, 1 ORDEM, UPPER(des_grupo_situacao) SITUACAO, round(nvl(cast((SUM(VLR_RESUMO)/1000) AS NUMERIC(15,2)),0),0) Valor
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

    PROCEDURE SP_SEL_BATIMENTO3_DETATLHADA( 
      P_CSP       VARCHAR2,
      P_MESREFI    VARCHAR2,
      P_MESREFF    VARCHAR2,
      P_GR_SIT    VARCHAR2,
      P_TAB_FATO  VARCHAR2,
      P_FILTROS   OUT SYS_REFCURSOR )
    IS
      V_FILTROS      SYS_REFCURSOR;
      V_QUERY        CLOB;
      V_QUERY_CSP    VARCHAR2(100);
      V_QUERY_MESREF VARCHAR2(100);
      V_QUERY_GR_SIT VARCHAR2(100);
    BEGIN

      IF RTRIM(LTRIM(NVL(P_CSP,'0'))) = '0' THEN 
         V_QUERY_CSP := ' OR 1=1)'; 
      ELSE 
         V_QUERY_CSP := ')'; 
      END IF;
    
      IF RTRIM(LTRIM(NVL(P_GR_SIT,'0'))) = '0' OR upper(RTRIM(LTRIM(NVL(P_GR_SIT,'0')))) = 'TODAS' THEN 
        V_QUERY_GR_SIT := ' OR 1=1)'; 
      ELSE 
        V_QUERY_GR_SIT := ')'; 
      END IF;

      V_QUERY := '
           SELECT DSH.CSP, 
                  DSH.DES_HOLDING       AS OPERADORA, 
                  DSH.UF, 
                  DSH.MES_REFERENCIA, 
                  DSH.CICLO             AS CICLO_NF, 
                  RPAD('''',50,'' '')   AS NOME_ARQUIVO, 
                  DSH.DES_SITUACAO      AS SITUACAO_GRUPO, 
                  DSH.QTD_ACIONAMENTOS, 
                  DSH.VLR_RESUMO, 
                  DSH.VLR_TCOF
                FROM T_TOT_DASHBOARD_FISCAL DSH
                WHERE DSH.TAB_TEMP = ''' || P_TAB_FATO || '''' || 
                     ' AND (DSH.CSP = ''' || P_CSP || '''' || V_QUERY_CSP ||
                     ' AND DSH.MES_REFERENCIA BETWEEN ''' || P_MESREFI || ''' AND ''' || P_MESREFF || '''' ||
                     ' AND (UPPER(DSH.DES_GRUPO_SITUACAO) = ''' || UPPER(P_GR_SIT) || '''' || V_QUERY_GR_SIT ||
                     ' AND DSH.DES_HOLDING IS NOT NULL ' ||
                     ' AND UPPER(DSH.DES_SITUACAO) <> ''RESUMO'' ';

      V_QUERY := V_QUERY || ' ORDER BY 1';
             
      OPEN V_FILTROS FOR V_QUERY;

      P_FILTROS := V_FILTROS;
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
        SELECT MES_REFERENCIA, des_grupo_situacao, CAST(Valor AS INTEGER) Valor FROM ( SELECT DSHA.MES_REFERENCIA, 
                               DSHA.des_grupo_situacao, 
--                               round(nvl(cast((SUM(nvl(DSHA.VLR_TCOF,1))/1000) AS NUMERIC(15,2)),0),0) Valor
--                               CAST(((SUM(nvl(DSHA.VLR_TCOF,1)) / CASE WHEN AVG(VLR_TCOF_TOT)>0 THEN AVG(VLR_TCOF_TOT) ELSE 1 END) *100) AS NUMERIC(3,0)) Valor
                                 CASE WHEN DSHA.des_grupo_situacao = 'Resumo' THEN CAST(sum(vlr_resumo)/1000 AS INTEGER) ELSE CAST(sum(DSHA.vlr_tcof)/1000  AS INTEGER) END / CAST(AVG(VLR_TCOF_TOT)/1000 AS INTEGER) * 100 Valor
                            FROM T_TOT_DASHBOARD_FISCAL DSHA
                            INNER JOIN (SELECT TAB_TEMP, MES_REFERENCIA, SUM(CASE WHEN des_grupo_situacao = 'Resumo' THEN nvl(VLR_RESUMO,0) ELSE nvl(VLR_TCOF,0) END) AS VLR_TCOF_TOT FROM T_TOT_DASHBOARD_FISCAL GROUP BY TAB_TEMP, MES_REFERENCIA) DSHB ON DSHB.TAB_TEMP=DSHA.TAB_TEMP AND DSHB.MES_REFERENCIA=DSHA.MES_REFERENCIA
                            WHERE DSHA.TAB_TEMP = P_TAB_FATO 
                                  AND DSHA.MES_REFERENCIA = trim(to_char(v_ano, '0000')) || trim(to_char(v_mes, '00'))
                            GROUP BY DSHA.MES_REFERENCIA, DSHA.DES_GRUPO_SITUACAO) FATO 
            ORDER BY 1,2;

        LOOP

          FETCH C_DADOS INTO V_DADOS_ANOMES, V_DADOS_SITUACAO, V_DADOS_VALOR;
          EXIT WHEN C_DADOS%NOTFOUND;
          V_ACHOU := 1;
          V_LINHA := V_lINHA || ',' || TO_CHAR(V_DADOS_VALOR) || ',''' || CASE WHEN V_DADOS_VALOR>=5 THEN RTRIM(LTRIM(TO_CHAR(V_DADOS_VALOR,'999'))) ELSE '' END || '''';

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

   PROCEDURE SP_SEL_GRAFICOBAIDU(
      P_TAB_FATO CHAR,
      P_GRAFICO_STR OUT CLOB )
    IS
      --VARIAVEIS DE TRABALHO
      V_SQL                  clob;           -- VARIAVEL COMANDOS SQL EXECUTE IMMEDIATE
      V_LINHA                CLOB;           -- LINHA DO GRAFICO DA SITUACAO ATUAL
      V_CMD_JS_VAR           CLOB;           -- COMANDO JS DE DECLARACAO DE VARIAVEIS
      V_CMD_JS_PUSH          CLOB;           -- COMANDO JS DE ATRIBUICAO DE VALORES
      V_CMD_JS_XAXIS         CLOB;           -- COMANDO JS DE ATRIBUICAO DE VALORES
      V_CMD_JS_LEGENDA       CLOB;           -- COMANDO JS DE ATRIBUICAO DE VALORES
      V_CMD_JS_OPTION        CLOB;
      V_CMD_JS_SERIES        CLOB;
      V_SITUACAO             VARCHAR(100);   -- CONTROLE DE QUEBRA
      C_DADOS                SYS_REFCURSOR;  -- CURSOR DE RETORNO COM DADOS DO GRAFICO
      V_DADOS_SITUACAO       VARCHAR2(50);   -- VARIAVEL DO FETCH DO CURSOR C_DADOS
      V_DADOS_MES_REFERENCIA VARCHAR2(6);    -- VARIAVEL DO FETCH DO CURSOR C_DADOS
      V_DADOS_VALOR          VARCHAR2(6);    -- VARIAVEL DO FETCH DO CURSOR C_DADOS
      V_PRIMEIRA_LINHA       CHAR(1);
    BEGIN

      V_SITUACAO       := 'INICIO';
      V_CMD_JS_VAR     := ' ';
      V_CMD_JS_PUSH    := ' ';
      V_CMD_JS_XAXIS   := ' ';
      V_CMD_JS_LEGENDA := ' ';
      V_CMD_JS_SERIES  := ' ';
      V_PRIMEIRA_LINHA := 'S';

      OPEN C_DADOS FOR 
      SELECT DSHA.DES_GRUPO_SITUACAO, 
             DSHA.MES_REFERENCIA, 
             CAST(((SUM(DSHA.VLR_RESUMO) / AVG(VLR_RESUMO_TOT)  )*100) AS INTEGER) AS VALOR 
             FROM T_TOT_DASHBOARD_FISCAL DSHA
             INNER JOIN (SELECT TAB_TEMP, MES_REFERENCIA, CAST(SUM(VLR_RESUMO) AS INTEGER) AS VLR_RESUMO_TOT FROM T_TOT_DASHBOARD_FISCAL WHERE DES_GRUPO_SITUACAO = 'Resumo' GROUP BY TAB_TEMP, MES_REFERENCIA) DSHB ON DSHB.TAB_TEMP=DSHA.TAB_TEMP AND DSHB.MES_REFERENCIA=DSHA.MES_REFERENCIA
             WHERE DSHA.TAB_TEMP = P_TAB_FATO 
             AND DES_GRUPO_SITUACAO <> 'Resumo'
             GROUP BY DSHA.DES_GRUPO_SITUACAO, DSHA.MES_REFERENCIA 
             ORDER BY 1, 2;
      LOOP
        FETCH C_DADOS INTO V_DADOS_SITUACAO, V_DADOS_MES_REFERENCIA, V_DADOS_VALOR;
        EXIT WHEN C_DADOS%NOTFOUND;

        --SE MUDAR SITUACAO, FAZ QUEBRA DELETE LINHA
        IF V_SITUACAO <> V_DADOS_SITUACAO THEN
          V_SITUACAO    := V_DADOS_SITUACAO;
          V_CMD_JS_VAR  := V_CMD_JS_VAR || 'var V_DATA_' || V_SITUACAO || ' = []; ';
          IF V_CMD_JS_PUSH <> ' ' THEN 
            V_CMD_JS_PUSH := V_CMD_JS_PUSH || ');'; 
          END IF;
          V_CMD_JS_PUSH := V_CMD_JS_PUSH || ' V_DATA_' || V_SITUACAO || '.push( ';
          
          --LEGENDA
          IF V_CMD_JS_LEGENDA = ' ' THEN
            V_CMD_JS_LEGENDA := 'var legOption = [''' || V_SITUACAO || '''';
          ELSE
            V_CMD_JS_LEGENDA := V_CMD_JS_LEGENDA || ', ''' || V_SITUACAO || '''';
          END IF;

          --SERIES
          IF V_CMD_JS_SERIES = ' ' THEN 
            V_CMD_JS_SERIES := '{ name: ''' ||V_SITUACAO||''', type: ''bar'', stack: ''one'', emphasis: emphasisStyle, data: V_DATA_' || V_SITUACAO || ', label: lblOption }';
          ELSE
            V_CMD_JS_SERIES := V_CMD_JS_SERIES || ',{ name: ''' ||V_SITUACAO||''', type: ''bar'', stack: ''one'', emphasis: emphasisStyle, data: V_DATA_' || V_SITUACAO || ', label: lblOption }';
          END IF;

          V_PRIMEIRA_LINHA := 'S';
        END IF;
        
        --PUSH
        IF V_PRIMEIRA_LINHA = 'S' THEN
          V_CMD_JS_PUSH := V_CMD_JS_PUSH || TO_CHAR(V_DADOS_VALOR);
        ELSE
           V_CMD_JS_PUSH := V_CMD_JS_PUSH || ',' || TO_CHAR(V_DADOS_VALOR);
        END IF;
        
        --XAXIS
        IF V_CMD_JS_XAXIS NOT LIKE '%'||V_DADOS_MES_REFERENCIA||'%' THEN
          IF V_CMD_JS_XAXIS = ' ' THEN
            V_CMD_JS_XAXIS := 'xAxisData.push(''' || TO_CHAR(V_DADOS_MES_REFERENCIA) ||'''';
          ELSE
            V_CMD_JS_XAXIS := V_CMD_JS_XAXIS || ',''' || TO_CHAR(V_DADOS_MES_REFERENCIA) ||'''';
          END IF;
        END IF;

        V_PRIMEIRA_LINHA := 'N';

      END LOOP; --C_DADOS
      v_cmd_js_var     := 'var xAxisData = []; ' || v_cmd_js_var || ' var emphasisStyle = { show: false, itemStyle: { barBorderWidth: 1, shadowBlur: 5, shadowOffsetX: 0, shadowOffsetY: 0, shadowColor: ''rgba(0,0,0,0.5)'' } };';
      v_cmd_js_var     := v_cmd_js_var || ' var lblOption = { show: true,  color:''#000000'',  align: ''center'',  verticalAlign: ''bottom'',  rotate:''00'', fontSize: 11, fontWeight: ''bold'' };';
      V_CMD_JS_PUSH    := V_CMD_JS_PUSH || ');'; 
      V_CMD_JS_XAXIS   := V_CMD_JS_XAXIS || ');'; 
      V_CMD_JS_LEGENDA := V_CMD_JS_LEGENDA || '];';
      V_CMD_JS_OPTION  := '
                          option = {
                          title: {text: '''', textAlign : ''auto''},
                          color: [''#6a9bd8'', ''#d86a6f'', ''#7dc581'', ''#e1914c'', ''#6600cc'', ''#cc00cc''],
                          width:''860px'',
                          height: ''200px'',
                          legend: {
                              data: legOption,
                              left: 20
                          },
                          toolbox: {
                              right: 00,
                              language: ''en'',
                              showTitle: true,
                              feature: {
                                  dataZoom: { title: { zoom: ''Zoom'', back: ''Volta 1 Passo'' }, yAxisIndex: ''none'' },
                                  restore: { title: ''Restaura'' },
                                  dataView: { title: ''Dados'', lang: [''Dados'', ''Fecha'', ''Atualiza''] },
                                  brush: {
                                      type: [''rect'',''clear''],
                                      title: { rect: ''Seleciona'', clear: ''Limpa Seleção'' },
                                      xAxisIndex: 0
                                  },
                                  saveAsImage: { title: ''Save as Image'' },
                                  magicType: {
                                      type: [''stack'', ''tiled''],
                                      title: { stack: ''Empilhado'', tiled: ''Lado a Lado'' }
                                  }
                              }
                          },
                          tooltip: {},
                          xAxis: { data: xAxisData, name: '''' },
                          yAxis: { inverse: false, splitArea: {show: true}, max: 100 },
                          grid: { left: 50 },
                          series: [';
      V_CMD_JS_OPTION := V_CMD_JS_OPTION || ' ' || V_CMD_JS_SERIES || ']}; myChart.setOption(option);';



      P_GRAFICO_STR := V_CMD_JS_VAR ||' '|| V_CMD_JS_LEGENDA || ' ' || V_CMD_JS_PUSH || ' ' || V_CMD_JS_XAXIS || ' ' || V_CMD_JS_OPTION;
      
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
          SELECT DISTINCT PIV.CSP, nvl(PIV.HOLDING, ' ') HOLDING, NVL(PIV.UF, '  ') UF, 
                 PIV.VLR_RESUMO, PIV.VLR_ACEITO, PIV.VLR_REJEITADO, PIV.VLR_RECEBIDO, PIV.VLR_PENDENTE,
                 ROUND(CASE WHEN NVL(VLR_TOTAL,0) = 0 THEN 0 ELSE (PIV.VLR_ACEITO    / VLR_RESUMO * 100) END, 2) AS PCT_ACEITO,
                 ROUND(CASE WHEN NVL(VLR_TOTAL,0) = 0 THEN 0 ELSE (PIV.VLR_REJEITADO / VLR_RESUMO * 100) END, 2) AS PCT_REJEITADO,
                 ROUND(CASE WHEN NVL(VLR_TOTAL,0) = 0 THEN 0 ELSE (PIV.VLR_RECEBIDO  / VLR_RESUMO * 100) END, 2) AS PCT_RECEBIDO,
                 ROUND(CASE WHEN NVL(VLR_TOTAL,0) = 0 THEN 0 ELSE (PIV.VLR_PENDENTE  / VLR_RESUMO * 100) END, 2) AS PCT_PENDENTE
              FROM ( 
              SELECT *
                  FROM (
                        SELECT DSH.CSP, 
                               DSH.DES_HOLDING AS HOLDING, 
                               DSH.UF,
                               UPPER(nvl(DSH.DES_GRUPO_SITUACAO, 'VLR_TOTAL')) AS DES_GRUPO_SITUACAO,
                               SUM(DSH.VLR_RESUMO) VLR_RESUMO
                            FROM T_TOT_DASHBOARD_FISCAL DSH
                            WHERE DSH.TAB_TEMP = P_TAB_FATO
                                  AND (DSH.CSP = P_CSP OR P_CSP IS NULL OR P_CSP = '0')
                                  AND (DSH.MES_REFERENCIA = P_MESREF OR P_MESREF IS NULL)
                                  AND (UPPER(DSH.DES_GRUPO_SITUACAO) = UPPER(P_GR_SIT) OR P_GR_SIT IS NULL OR P_GR_SIT = 'Todas')
                                  AND DSH.DES_HOLDING IS NOT NULL
                            GROUP BY cube(DSH.CSP, DSH.DES_HOLDING, DSH.UF, DSH.DES_GRUPO_SITUACAO)
                                 HAVING (CSP IS NOT NULL AND DES_HOLDING IS NOT NULL) OR (CSP IS NOT NULL AND DES_HOLDING IS NULL AND UF IS NULL)
--                                 HAVING CSP IS NOT NULL AND DES_HOLDING IS NOT NULL AND MES_REFERENCIA IS NOT NULL AND UF IS NOT NULL AND CICLO IS NOT NULL
                       ) DET
              PIVOT (
                        SUM(DET.VLR_RESUMO)
                        FOR (DES_GRUPO_SITUACAO) IN ( 'RESUMO' AS "VLR_RESUMO", 'ACEITO' AS "VLR_ACEITO", 'REJEITADO' AS "VLR_REJEITADO", 'RECEBIDO' AS "VLR_RECEBIDO", 'PENDENTE' AS "VLR_PENDENTE", 'VLR_TOTAL' AS "VLR_TOTAL")
                    )
              ) PIV
              WHERE (NVL(PIV.VLR_ACEITO,0) + NVL(PIV.VLR_REJEITADO,0) + NVL(PIV.VLR_RECEBIDO,0) + NVL(PIV.VLR_PENDENTE,0)) > 0 
              ORDER BY 1,2,3;

      P_FILTROS := V_FILTROS;
   END;

END PKG_DASHBOARD_FISCAL;

--select * from SYS.USER_ERRORS where NAME = 'PKG_DASHBOARD_FISCAL' --and type = 'PROCEDURE'
--TRUNCATE TABLE tmp_pivot;
--DROP TABLE tmp_pivot;
