SELECT * from SYS.USER_ERRORS where NAME = 'SP_UPD_CARREGA_VALIDADOR' ;

CREATE OR REPLACE PROCEDURE SCH_C31DB31."SP_UPD_CARREGA_VALIDADOR" (
      P_DAT_INI IN OUT VARCHAR
    , P_DAT_FIM IN OUT VARCHAR
    , TAG_FORCAEXEC    CHAR DEFAULT 'N'
) IS 
 SQL_CODE             NUMBER(10);-- CODIGO DO ERRO SQL
 SQL_MESSAGE          VARCHAR2(255);       -- MENSAGEM DE ERRO
 V_NOM_BANCO          CHAR(18);           -- NOME DO BANCO QUE ESTA EXECUTANDO A ROTINA
 V_NOM_ROTINA         CHAR(18);           -- NOME DA ROTINAQUE ESTA SENDO EXECUTADA
 --CONTROLE DE CRIACAO DAS TABELAS TEMPORARIAS
 V_TMP1_RET           NUMBER(10);
 V_TMP2_RET           NUMBER(10);

 --TABELAS TEMPORARIAS
 V_TMP1               VARCHAR2(30);
 V_TMP2               VARCHAR2(30);

 V_QUERY              CLOB;
 V_CONTA              NUMBER;

BEGIN

EXECUTE IMMEDIATE 'alter session set events ''8103 trace name errorstack level 3'' ';

--INICIALIZA AS VARIAVEIS
V_NOM_ROTINA := UPPER('SP_UPD_CARREGA_VALIDADOR');
V_TMP1_RET := 0;
V_TMP2_RET := 0;

--GERANDO O NOME DAS TEMPORARIAS
SELECT sps_NomeTabTemp('TMP1') INTO V_TMP1 FROM DUAL;
SELECT sps_NomeTabTemp('TMP2') INTO V_TMP2 FROM DUAL;

--PEGA O NOME DO BANCO EM QUE ESTA EXECUTANDO A ROTINA
SELECT SYS_CONTEXT ('USERENV', 'SESSION_USER') 
INTO V_NOM_BANCO
FROM DUAL;

--VERIFICA SE EXISTE A LINHA NA TABELA T_SEMAFORO PARA CONTROLE DE EXECUCAO
SELECT COUNT(*)
INTO V_CONTA
FROM T_SEMAFORO
WHERE NOM_ROTINA = V_NOM_ROTINA;

IF V_CONTA = 0 THEN
    --SE NAO EXISTE INCLUI LINHA NA TABELA T_SEMAFORO PARA CONTROLE DE EXECUCAO
    INSERT INTO T_SEMAFORO VALUES( V_NOM_ROTINA, NULL, NULL, 0);
END IF;

--SE TAG FORCA EXECUCAO FOR N VERIFICA SE A ROTINA ESTA EM EXECUCAO
IF TAG_FORCAEXEC = 'N' THEN
  SELECT COUNT(*)
  INTO V_CONTA
  FROM T_SEMAFORO
  WHERE NOM_ROTINA = V_NOM_ROTINA
  AND COD_SINAL = 1
  ;
  IF V_CONTA > 0 THEN
    -- SE EXISTIR SAI DA ROTINA AVISANDO QUE A MESMA PODE ESTAR EM EXECUCAO
    -- OU TERMINOU COM ERRO NO ULTIMO PROCESSAMENTO
    dbms_output.put_line( '-99999, ATENCAO A ROTINA ' 
       || TRIM(V_NOM_ROTINA)
       || TRIM( V_NOM_BANCO )
       || ' JA ESTA EM EXECUCAO OU TERMINOU COM ERRO NO ULTIMO PROCESSAMENTO'
       || ', PARA FORCAR A EXECUCAO CHAME A ROTINA COM O TERCEIRO PARAMETRO IGUAL A S'
       );
    RETURN;
  END IF;
END IF;

--ATUALIZA A TABELA T_SEMAFORO COM A DATA DE INICIO DA EXECUGAO
UPDATE T_SEMAFORO
SET DAT_INI = SYSDATE
, COD_SINAL = 1
WHERE UPPER(NOM_ROTINA) = UPPER(V_NOM_ROTINA);
COMMIT;

-- VERIFICA A DATA INICIAL
IF TRIM( P_DAT_INI ) IS NULL THEN
    SELECT 
         TO_CHAR( NVL(MIN(DAT_EMISSAONF), SYSDATE), 'YYYY-MM-DD HH24:MI:SS'),
         TO_CHAR( NVL(MAX(DAT_EMISSAONF), SYSDATE), 'YYYY-MM-DD HH24:MI:SS')
    INTO P_DAT_INI, P_DAT_FIM
    FROM T_CTRL_ARQ_FISCAIS;
END IF;

--APAGA REGISTROS ANTERIORES REFERENTE AO PER�ODO
DELETE FROM T_VALIDADOR_FISCAL WHERE (DAT_EMISSAONF BETWEEN P_DAT_INI AND P_DAT_FIM OR P_DAT_INI IS NULL);

V_QUERY := 'CREATE GLOBAL TEMPORARY TABLE ' || V_TMP1 || ' ON COMMIT PRESERVE ROWS AS
SELECT /*+ PARALLEL( 10) */ SEQ_RECEPCAO,
   COD_SERIENF,
   COD_SUBSERIENF,
   SOL.DES_STATUS_ENVIO,
   CASE
     WHEN NVL(SOL.DES_STATUS_ENVIO, ''A'') = ''A'' AND
          SOL.IDSOLIC IS NOT NULL THEN ''Autom�tico''
     WHEN SOL.DES_STATUS_ENVIO IN (''E'', ''R'') AND SOL.IDSOLIC IS NOT NULL THEN ''Manual''
   END TIPO_ENVIO,
   SOL.DAT_ENVIO,
   CASE
     WHEN SOL.IDSOLIC IS NOT NULL THEN 1
   ELSE 0
   END + (SELECT COUNT(*)
            FROM T_EMAIL_CONTROLEENVIO_HIST SOLH
           WHERE SOLH.ID_SEQ_RECEPCAO = TMP.SEQ_RECEPCAO) QTD_ENVIO,
   NF_INICIAL,
   NF_FINAL,
   QTD_NOTA,
   VLR_TOTAL,
   VLR_TOTAL_CANCELADO,
   BAS_CAL_ICMSNF,
   VLR_ICMSNF,
   VLR_ISENTONF,
   VLR_OUTROSNF
FROM (SELECT AF.SEQ_RECEPCAO, 
         SNF.COD_SERIENF,
         SNF.COD_SUBSERIENF,
         MIN(SNF.NF_INICIAL) NF_INICIAL,
         MAX(SNF.NF_FINAL) NF_FINAL,
         SUM(SNF.QTD_NOTA) QTD_NOTA,
         SUM(SNF.VLR_TOTAL) VLR_TOTAL,
         SUM(SNF.VLR_TOTAL_CANCELADO) VLR_TOTAL_CANCELADO,
         NVL(SUM(SNF.BAS_CAL_ICMSNF), 0) BAS_CAL_ICMSNF,
         NVL(SUM(SNF.VLR_ICMSNF), 0) VLR_ICMSNF,
         NVL(SUM(SNF.VLR_ISENTONF), 0) VLR_ISENTONF,
         NVL(SUM(SNF.VLR_OUTROSNF), 0) VLR_OUTROSNF
    FROM T_CTRL_ARQ_FISCAIS AF
   INNER JOIN T_SERIE_SUBS_NF SNF ON AF.SEQ_RECEPCAO = SNF.SEQ_RECEPCAO
   INNER JOIN T_EMPRESA EMPLD ON AF.COD_EOT_LD = EMPLD.COD_EOTEMP
   INNER JOIN T_EMPRESA EMPCB ON AF.COD_EOT_CB = EMPCB.COD_EOTEMP
   WHERE NVL(AF.STATUS_CARGA, 0) = 0
     AND NVL(AF.QTD_NOTA, 0) > 0
     AND AF.COD_CONTRATANTE IN
         (SELECT SIGLA_HOLDING
            FROM T_EMPRESA
           WHERE COD_EOTPAISEMP LIKE ''%h31;%''
           GROUP BY SIGLA_HOLDING)
           AND (AF.DAT_EMISSAONF BETWEEN TO_DATE(''||P_DAT_INI||'', ''DD/MM/YYYY'') AND TO_DATE('''|| P_DAT_FIM ||''', ''DD/MM/YYYY'')
   GROUP BY AF.SEQ_RECEPCAO, SNF.COD_SERIENF, SNF.COD_SUBSERIENF) TMP
LEFT JOIN T_EMAIL_CONTROLEENVIO SOL ON TMP.SEQ_RECEPCAO = SOL.ID_SEQ_RECEPCAO';

EXECUTE IMMEDIATE V_QUERY;

V_QUERY := 'CREATE GLOBAL TEMPORARY TABLE '|| V_TMP2 ||' ON COMMIT PRESERVE ROWS AS
SELECT /*+ PARALLEL( 10) */ AF.SEQ_RECEPCAO,
   SNF.TIPO_ENVIO,
   SNF.DAT_ENVIO,
   SNF.QTD_ENVIO,
   EMPLD.NOM_FANTASIAEMP NOM_LD,
   SHLD.DES_HOLDING HOLDING_LD,
   EMPLD.SIGLA_HOLDING SIGLA_LD,
   EMPLD.COD_EOTEMP EOT_LD,
   EMPCB.NOM_FANTASIAEMP NOM_COB,
   SHCB.DES_HOLDING HOLDING_COB,
   EMPCB.SIGLA_HOLDING SIGLA_CB,
   EMPCB.COD_EOTEMP EOT_CB,
   TO_CHAR(AF.DAT_EMISSAONF, ''YYYYMM'') ANO_MES_EMISSAONF,
   EMPCB.COD_UFEMP UF_COB,
   SNF.NF_INICIAL,
   SNF.NF_FINAL,
   SNF.QTD_NOTA,
   (NVL(SNF.NF_FINAL, 0) - NVL(SNF.NF_INICIAL, 0) + 1) QTD_NOTA_CALC,
   AF.CICLO_NF,
   SNF.COD_SERIENF,
   SNF.COD_SUBSERIENF,
   ''N'' PRIMLINHAGRUPO,
   ''N'' ULTLINHAGRUPO,
   CAST('' '' AS VARCHAR2(30)) SEMSEQUENCIA,
   CAST('' '' AS VARCHAR2(30)) INICIAEM1,
   CAST('' '' AS VARCHAR2(30)) TERMINAEM,
   CAST('' '' AS VARCHAR2(30)) DUPLICADO,
   AF.DSN_ORIGINAL,
   AF.DSN_CLIENTE,
   TO_CHAR(AF.DAT_PROCESSAMENTO, ''DD/MM/YYYY HH24:MI:SS'') DAT_PROCESSAMENTO,
   NVL(AF.COD_CRITICA2, 0) COD_CRITICA,
   ERRCRIT.DES_CRITICA,
   NVL(AF.STATUS_CRITPROT, 0) STATUS_CRITPROT,
   CRITPROTOCOLO.DES_CRITICA DES_STATUSCRI,
   NVL(AF.STATUS_CARGA, -1) STATUS_CARGA,
   ERRCARGA.DES_CRITICA DES_CARGA,
   TO_CHAR(ARQ.DAT_CARGA, ''DD/MM/YYYY HH24:MI:SS'') DAT_CARGA,
   SNF.VLR_TOTAL,
   SNF.VLR_TOTAL_CANCELADO,
   NVL(SNF.BAS_CAL_ICMSNF, 0) VLR_BASE_ICMS,
   NVL(SNF.VLR_ICMSNF, 0) VLR_ICMS,
   NVL(SNF.VLR_ISENTONF, 0) VLR_ISENTA,
   NVL(SNF.VLR_OUTROSNF, 0) VLR_OUTRA,
   CASE
     WHEN NVL(SNF.VLR_TOTAL - (SNF.BAS_CAL_ICMSNF + SNF.VLR_ISENTONF + SNF.VLR_OUTROSNF), 0) <> 0 THEN ''N�O OK''
     ELSE ''OK''
   END VALIDA_VLR,
   NVL(SNF.VLR_TOTAL - SNF.BAS_CAL_ICMSNF + SNF.VLR_ISENTONF + SNF.VLR_OUTROSNF), 0) VLR_VALIDAVLR,
   AF.DAT_EMISSAONF DAT_EMISSAONF,
   TRIM(EMPLD.SIGLA_HOLDING) || '';'' || TRIM(EMPCB.SIGLA_HOLDING) || '';'' ||
   EMPCB.COD_UFEMP || '';'' || SNF.COD_SERIENF || '';'' ||
   SNF.COD_SUBSERIENF CHAVE_VNF,
   TRIM(EMPLD.COD_EOTEMP) || '';'' || TRIM(EMPCB.COD_EOTEMP) || '';'' ||
   AF.DAT_EMISSAONF || '';'' || EMPCB.COD_UFEMP || '';'' ||
   SNF.COD_SERIENF || '';'' || SNF.COD_SUBSERIENF || '';'' || AF.CICLO_NF CHAVE_DUP,
   AF.DSN_RECEPCAO,
   TO_CHAR(AF.DAT_RECEPCAO, ''DD/MM/YYYY HH24:MI:SS'') DAT_RECEPCAO,
   AF.DSN_TRANSMISSAO,
   TO_CHAR(AF.DAT_TRANSMISSAO, ''DD/MM/YYYY HH24:MI:SS'') DAT_TRANSMISSAO,
   AF.STATUS_TRANSM,
   FR.NOM_FORNECEDOR,
   CAST(0 AS NUMBER(2)) NUM_ARQRESUMO,
   CAST('' '' AS VARCHAR2(20)) NOM_ARQRESUMO,
   CAST('' '' AS VARCHAR2(20)) DAT_GERACAORESUMO,
   CASE
     WHEN SNF.QTD_NOTA <> NVL(SNF.NF_FINAL, 0) - NVL(SNF.NF_INICIAL, 0) + 1) THEN 1
     ELSE 0
   END NF_FALTANTES
FROM T_CTRL_ARQ_FISCAIS AF
INNER JOIN T_STATUS_CONTROLE STATUSREC ON AF.STATUS_RECEPCAO = STATUSREC.COD_STATUS
INNER JOIN T_EMPRESA EMPLD ON AF.COD_EOT_LD = EMPLD.COD_EOTEMP
INNER JOIN T_SIGLA_HOLDING SHLD ON EMPLD.SIGLA_HOLDING = SHLD.SIGLA_HOLDING
INNER JOIN T_EMPRESA EMPCB ON AF.COD_EOT_CB = EMPCB.COD_EOTEMP
INNER JOIN T_SIGLA_HOLDING SHCB ON EMPCB.SIGLA_HOLDING = SHCB.SIGLA_HOLDING
LEFT JOIN T_STATUS_CONTROLE STATUSCRI ON AF.STATUS_CRITICA = STATUSCRI.COD_STATUS
LEFT JOIN T_STATUS_CONTROLE STATUSTRANS ON AF.STATUS_TRANSM = STATUSTRANS.COD_STATUS
LEFT JOIN T_ERRO_CRITICA ERRCRIT ON AF.COD_CRITICA2 = ERRCRIT.COD_CRITICA
LEFT JOIN T_ERRO_CRITICA ERRCARGA ON AF.STATUS_CARGA = ERRCARGA.COD_CRITICA
LEFT JOIN C31DB31.T_ARQUIVO ARQ ON AF.SEQ_RECEPCAO = ARQ.SEQ_RECEPCAO
LEFT JOIN T_ERRO_CRITICA ERRRECP ON AF.COD_CRITICA = ERRRECP.COD_CRITICA
LEFT JOIN T_CRITPROTOCOLO CRITPROTOCOLO ON AF.STATUS_CRITPROT = CRITPROTOCOLO.COD_CRITICA
INNER JOIN '|| V_TMP1 ||' SNF ON AF.SEQ_RECEPCAO = SNF.SEQ_RECEPCAO
INNER JOIN T_FORNECEDOR FR ON AF.COD_REMETENTE = FR.COD_FORNECEDOR'; 

EXECUTE IMMEDIATE V_QUERY;

/*Apagando os FISC.REJEITA que tem FISC.RECEBID*/
V_QUERY := 'DELETE '|| V_TMP2 ||'
  WHERE COD_CRITICA = 0
        AND STATUS_CRITPROT = ''FJ''
        AND CHAVE_DUP IN (SELECT CHAVE_DUP
                           FROM TMP_233914_VNF
                          WHERE COD_CRITICA = 0
                            AND STATUS_CRITPROT = ''FR'')';
EXECUTE IMMEDIATE V_QUERY;

--CREATE GLOBAL TEMPORARY TABLE T_VALIDADOR_FISCAL ON COMMIT PRESERVE ROWS AS
--DROP TABLE T_VALIDADOR_FISCAL;
V_QUERY := 'INSERT INTO T_VALIDADOR_FISCAL NOLOGGING AS
      SELECT tabtot.*, 
             CASE
               WHEN COD_CRITICA = 0 AND NVL(STATUS_CRITPROT,''0'') NOT IN (''FR'',''FJ'') THEN 2
               WHEN STATUS_CRITPROT = ''FR'' THEN 1
               WHEN COD_CRITICA <> 0  OR STATUS_CRITPROT = ''FJ'' THEN 3
               ELSE 9
             END COD_SIT
      FROM (
            SELECT 1 TIPO_REGISTRO, NCRIT.*
              FROM '|| V_TMP2 ||' NCRIT
             WHERE NVL(TRIM(NCRIT.NUM_ARQRESUMO), 0) > 0
            UNION
            SELECT *
              FROM (SELECT 1 TIPO_REGISTRO, NCRIT.*
                      FROM TMP_233914_VNF NCRIT
                     WHERE NCRIT.COD_CRITICA = 0
                    UNION ALL
                    SELECT 1 TIPO_REGISTRO, CRIT.*
                      FROM TMP_233914_VNF CRIT
                     WHERE CRIT.COD_CRITICA <> 0
                       AND CRIT.SEQ_RECEPCAO || '';'' || CRIT.CHAVE_DUP IN
                           (SELECT ULT_SEQ_RECEPCAO || '';'' || CHAVE_DUP
                              FROM (SELECT MAX(SEQ_RECEPCAO) ULT_SEQ_RECEPCAO, CHAVE_DUP
                                      FROM TMP_233914_VNF
                                     WHERE COD_CRITICA <> 0
                                       AND CHAVE_DUP NOT IN
                                           (SELECT CHAVE_DUP
                                              FROM TMP_233914_VNF
                                             WHERE COD_CRITICA = 0)
                                     GROUP BY CHAVE_DUP))) NF
          ) tabtot';
EXECUTE IMMEDIATE V_QUERY;

/*Fazendo as atualizacoes para contemplar as colunas PrimLinhaGrupo, UltLinhaGrupo, IniciaEm1, TerminaEm e SemSequencia*/ /*--primeira linha do grupo*/
UPDATE T_VALIDADOR_FISCAL
SET PRIMLINHAGRUPO = 'S'
WHERE LPAD(NF_INICIAL, 10, '0') || ';' || CHAVE_VNF IN
      (SELECT MIN(LPAD(NF_INICIAL, 10, '0') || ';' || CHAVE_VNF)
         FROM T_VALIDADOR_FISCAL
         GROUP BY CHAVE_VNF); /*--ultima linha do grupo*/

UPDATE T_VALIDADOR_FISCAL
  SET ULTLINHAGRUPO = 'S'
  WHERE LPAD(NF_FINAL, 10, '0') || ';' || CHAVE_VNF IN
        (SELECT MAX(LPAD(NF_FINAL, 10, '0') || ';' || CHAVE_VNF)
           FROM T_VALIDADOR_FISCAL
           WHERE 0 = 0
   GROUP BY CHAVE_VNF); /*--ultima linha do grupo*/

UPDATE T_VALIDADOR_FISCAL
  SET ULTLINHAGRUPO = 'S'
  WHERE LPAD(NF_FINAL, 10, '0') || ';' || CHAVE_VNF IN
        (SELECT MAX(LPAD(NF_FINAL, 10, '0') || ';' || CHAVE_VNF)
           FROM T_VALIDADOR_FISCAL
           WHERE 0 = 0
   GROUP BY CHAVE_VNF); /*--atualiza a ultima linha com TerminaEm*/

UPDATE T_VALIDADOR_FISCAL
  SET TERMINAEM = UF_COB || ' em ' || NF_FINAL
  WHERE ULTLINHAGRUPO = 'S'; /*--atualiza o SemSequencia*/ /*-- atualiza para a ultima linha do grupo*/

UPDATE T_VALIDADOR_FISCAL
   SET SEMSEQUENCIA = (CASE WHEN QTD_NOTA <> QTD_NOTA_CALC THEN 'N�o OK' ELSE 'OK' END)
   WHERE ULTLINHAGRUPO = 'S'; /*--atualiza para as linhas que n�o s�o a ultima SemSequencia = 'OK'*/

UPDATE T_VALIDADOR_FISCAL
  SET SEMSEQUENCIA = 'OK'
  WHERE ULTLINHAGRUPO = 'N'
        AND LPAD(NF_FINAL + 1, 10, '0') || ';' || CHAVE_VNF IN
            (SELECT LPAD(NF_INICIAL, 10, '0') || ';' || CHAVE_VNF
               FROM T_VALIDADOR_FISCAL); /*--atualiza para as linhas que n�o s�o a ultima SemSequencia = 'N�o OK'*/

UPDATE T_VALIDADOR_FISCAL
  SET SEMSEQUENCIA = 'N�o OK'
  WHERE ULTLINHAGRUPO = 'N'
        AND LPAD(NF_FINAL + 1, 10, '0') || ';' || CHAVE_VNF NOT IN
            (SELECT LPAD(NF_INICIAL, 10, '0') || ';' || CHAVE_VNF
               FROM T_VALIDADOR_FISCAL); /*--atualiza duplicidade de chaves*/

UPDATE T_VALIDADOR_FISCAL
  SET DUPLICADO = 'N�o OK'
  WHERE CHAVE_DUP IN 
       (SELECT CHAVE_DUP
          FROM T_VALIDADOR_FISCAL
          GROUP BY CHAVE_DUP
          HAVING COUNT(*) > 1);

--ATUALIZA A TABELA T_SEMAFORO COM A DATA DE FIM DA EXECUGAO
UPDATE T_SEMAFORO
SET COD_SINAL = 0
, DAT_FIM = SYSDATE
WHERE UPPER(NOM_ROTINA) = UPPER( V_NOM_ROTINA );
COMMIT;

-- DROPA AS TABELAS TEMPORARIAS
IF V_TMP1_RET = 1 THEN
  EXECUTE IMMEDIATE 'TRUNCATE TABLE ' || V_TMP1;
  EXECUTE IMMEDIATE 'DROP TABLE ' || V_TMP1;
  V_TMP1_RET := 0;
END IF;
IF V_TMP2_RET = 1 THEN
  EXECUTE IMMEDIATE 'TRUNCATE TABLE ' || V_TMP2;
  EXECUTE IMMEDIATE 'DROP TABLE ' || V_TMP2;
  V_TMP2_RET := 0;
END IF;

dbms_output.put_line( 'ROTINA ' || TRIM(V_NOM_ROTINA)
       || TRIM( V_NOM_BANCO )
       || ': CONCLUIDA COM SUCESSO!'
       );

EXCEPTION
 WHEN OTHERS THEN
  SQL_CODE := SQLCODE;
  SQL_MESSAGE := TRIM(SUBSTR(SQLERRM, 1, 200));

  ROLLBACK;

  IF V_TMP1_RET = 1 THEN
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ' || V_TMP1;
    EXECUTE IMMEDIATE 'DROP TABLE ' || V_TMP1;
    V_TMP1_RET := 0;
  END IF;
  IF V_TMP2_RET = 1 THEN
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ' || V_TMP2;
    EXECUTE IMMEDIATE 'DROP TABLE ' || V_TMP2;
    V_TMP2_RET := 0;
  END IF;
  dbms_output.put_line(SQL_CODE
         || ', ROTINA ' || TRIM(V_NOM_ROTINA)
         || TRIM( V_NOM_BANCO )
         || ': ' || TRIM(SQL_MESSAGE)
         || ' - ' || dbms_utility.format_error_backtrace
         );

END;

/*COMMIT;
TRUNCATE TABLE TMP_233914_VNF;
DROP TABLE TMP_233914_VNF;
TRUNCATE TABLE TMP_233913_SSUBVNF;
DROP TABLE TMP_233913_SSUBVNF;
DROP TABLE TMP_233915_RESULT;

UPDATE TMP_233915_RESULT SET des_sit = 'Recebido' WHERE trim(des_sit) IN ('98', '0')
COMMIT;
SELECT SYSDATE FROM dual;
SELECT COUNT(1) FROM TMP_233913_SSUBVNF;
SELECT COUNT(1) FROM TMP_233914_VNF;
CREATE GLOBAL TEMPORARY TABLE TMP_233913_SSUBVNF ON COMMIT PRESERVE ROWS AS 
*/
