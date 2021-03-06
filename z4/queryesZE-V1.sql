
--BATENDO RESUMO COM FISCAL COM A CHAVE COMPLETA
--CREATE GLOBAL TEMPORARY TABLE TMP_DET_DASH ON COMMIT PRESERVE ROWS AS
--SELECT * FROM TMP_DET_DASH
TRUNCATE TABLE TMP_DET_DASH;
DROP TABLE TMP_DET_DASH;
--INSERT INTO TMP_DET_DASH 
SELECT * FROM SOLICITACAO_CARGA_PRE_GFX_BRT sol
      INNER JOIN T_SIGLA_HOLDING_BRT HC ON HC.SIGLA_HOLDING = SOL.COD_HOLDING
      INNER JOIN RESUMO_FISCAL_GFX_BRT DET ON SOL.ID_CARGA = DET.ID_CARGA 
       WHERE mes_referencia='202003' AND cod_holding='VIV' AND tipo_demonstrativo = 'RESU' AND uf = 'DF' AND ciclo = 1;

CREATE GLOBAL TEMPORARY TABLE TMP_DET_DASH ON COMMIT PRESERVE ROWS AS
SELECT 
GFX.*, AF.CICLO_NF, NVL( AF.DES_SIT, 'Pendente') DES_SIT, AF.DSN_ORIGINAL, AF.VLR_TOTAL
, AF.SIGLA_CB, AF.ANO_MES_EMISSAONF, AF.UF_COB
    FROM (

      SELECT 
      ROW_NUMBER() OVER ( ORDER BY SOL.COD_HOLDING  ) LINHA_GFX,
      SOL.COD_HOLDING, 
      HC.DES_HOLDING, 
      SOL.MES_REFERENCIA, 
      DET.UF, 
      DET.CICLO, 
      SUM(VALOR_CONTABIL) VLR_RESUMO
      FROM SOLICITACAO_CARGA_PRE_GFX_BRT SOL
      INNER JOIN T_SIGLA_HOLDING_BRT HC ON HC.SIGLA_HOLDING = SOL.COD_HOLDING
      INNER JOIN RESUMO_FISCAL_GFX_BRT DET ON SOL.ID_CARGA = DET.ID_CARGA 
      AND SOL.TIPO_DEMONSTRATIVO = 'RESU'
      WHERE 0=0
      AND SOL.MES_REFERENCIA BETWEEN '202001' AND '202003'
--      AND SIGLA_HOLDING in ('', 'TLA')
--      AND UF = 'MA'
--      AND NVL(CICLO,0) = 0 --IN( 1,5 )
      GROUP BY SOL.COD_HOLDING, HC.DES_HOLDING, SOL.MES_REFERENCIA
      , DET.UF
      , DET.CICLO

    ) GFX
    JOIN 
         (
         SELECT DISTINCT
           SIGLA_CB, 
           ANO_MES_EMISSAONF,
           UF_COB,
           CICLO_NF,
           DES_SIT,
           T.DSN_ORIGINAL,
           T.VLR_TOTAL
         FROM SCH_C14DB14.TMP_233915_RESULT T
         WHERE ANO_MES_EMISSAONF BETWEEN '202001' AND '202003'
--           AND EOT_LD = '061'
--         AND SIGLA_CB in ('', 'TLA')
--         AND T.UF_COB = 'MA'
--         AND T.CICLO_NF = 1
/*
         SELECT
           SIGLA_CB, 
           ANO_MES_EMISSAONF,
           UF_COB,
           CICLO_NF,
           LISTAGG( DES_SIT, ', ') WITHIN GROUP (ORDER BY DES_SIT ) DES_SIT
         FROM (
         SELECT
           SIGLA_CB, 
           ANO_MES_EMISSAONF,
           UF_COB,
           CICLO_NF,
           DES_SIT
         FROM SCH_C14DB14.TMP_233915_RESULT T
         WHERE ANO_MES_EMISSAONF BETWEEN '202001' AND '202001'
         AND SIGLA_CB in ('', 'VIV')
         AND T.UF_COB = 'DF'
         AND T.CICLO_NF = 1
         GROUP BY 
           SIGLA_CB
           , ANO_MES_EMISSAONF
           , T.UF_COB
           , T.CICLO_NF
           , DES_SIT
           )
         GROUP BY 
           SIGLA_CB
           , ANO_MES_EMISSAONF
           , UF_COB
           , CICLO_NF
*/           
           ) AF
     ON AF.SIGLA_CB = GFX.COD_HOLDING
        AND ANO_MES_EMISSAONF = GFX.MES_REFERENCIA
        AND AF.UF_COB = GFX.UF
        AND AF.CICLO_NF = GFX.CICLO
    WHERE 0=0
    ORDER BY 1
;

--BATENDO RESUMO COM FISCAL COM A CHAVE SEM O CICLO PARA 
--   OS RESUMOS E FISCAIS QUE NAO BATERAM NA PRIMEIRA ETAPA
INSERT INTO TMP_DET_DASH 
SELECT 
GFX.*
, AF.CICLO_NF,  DES_SIT, AF.DSN_ORIGINAL, AF.VLR_TOTAL
, AF.SIGLA_CB, AF.ANO_MES_EMISSAONF, AF.UF_COB
FROM 
(
      SELECT 
      ROW_NUMBER() OVER ( ORDER BY SOL.COD_HOLDING  ) LINHA_GFX,
      SOL.COD_HOLDING, 
      HC.DES_HOLDING, 
      SOL.MES_REFERENCIA, 
      DET.UF, 
      DET.CICLO, 
      SUM(VALOR_CONTABIL) VLR_RESUMO
      FROM SOLICITACAO_CARGA_PRE_GFX_BRT SOL
      INNER JOIN T_SIGLA_HOLDING_BRT HC ON HC.SIGLA_HOLDING = SOL.COD_HOLDING
      INNER JOIN RESUMO_FISCAL_GFX_BRT DET ON SOL.ID_CARGA = DET.ID_CARGA 
      AND SOL.TIPO_DEMONSTRATIVO = 'RESU'
      WHERE 0=0
      AND SOL.MES_REFERENCIA BETWEEN '202001' AND '202003'
--      AND SIGLA_HOLDING in ('', 'TLA')
--      AND UF = 'MA'
--      AND NVL(CICLO,0) = 0 --IN( 1,5 )
       AND NOT EXISTS (
             SELECT 1
             FROM TMP_DET_DASH TMP 
             WHERE TMP.COD_HOLDING = SOL.COD_HOLDING
             AND TMP.MES_REFERENCIA = SOL.MES_REFERENCIA
             AND TMP.UF = DET.UF
             AND TMP.CICLO = DET.CICLO
             )
      GROUP BY SOL.COD_HOLDING, HC.DES_HOLDING, SOL.MES_REFERENCIA
      , DET.UF
      , DET.CICLO
    ) GFX
    LEFT JOIN 
         (
         SELECT DISTINCT
           SIGLA_CB, 
           ANO_MES_EMISSAONF,
           UF_COB,
           CICLO_NF,
           DES_SIT,
           T.DSN_ORIGINAL,
           T.VLR_TOTAL
         FROM SCH_C14DB14.TMP_233915_RESULT T
         WHERE ANO_MES_EMISSAONF BETWEEN '202001' AND '202003'
--           AND EOT_LD = '061'
--         AND SIGLA_CB in ('', 'TLA')
--         AND T.UF_COB = 'MA'
         AND NOT EXISTS (
               SELECT 1
               FROM TMP_DET_DASH TMP
               WHERE TMP.SIGLA_CB = T.SIGLA_CB
               AND TMP.ANO_MES_EMISSAONF = T.ANO_MES_EMISSAONF
               AND TMP.UF_COB = T.UF_COB
               AND TMP.CICLO_NF = T.CICLO_NF
               )

--         AND T.CICLO_NF = 1
/*
         SELECT
           SIGLA_CB, 
           ANO_MES_EMISSAONF,
           UF_COB,
           CICLO_NF,
           LISTAGG( DES_SIT, ', ') WITHIN GROUP (ORDER BY DES_SIT ) DES_SIT
         FROM (
         SELECT
           SIGLA_CB, 
           ANO_MES_EMISSAONF,
           UF_COB,
           CICLO_NF,
           DES_SIT
         FROM SCH_C14DB14.TMP_233915_RESULT T
         WHERE ANO_MES_EMISSAONF BETWEEN '202001' AND '202001'
         AND SIGLA_CB in ('', 'VIV')
         AND T.UF_COB = 'DF'
         AND T.CICLO_NF = 1
         GROUP BY 
           SIGLA_CB
           , ANO_MES_EMISSAONF
           , T.UF_COB
           , T.CICLO_NF
           , DES_SIT
           )
         GROUP BY 
           SIGLA_CB
           , ANO_MES_EMISSAONF
           , UF_COB
           , CICLO_NF
*/           
           ) AF
     ON AF.SIGLA_CB = GFX.COD_HOLDING
        AND ANO_MES_EMISSAONF = GFX.MES_REFERENCIA
        AND AF.UF_COB = GFX.UF
--        AND AF.CICLO_NF = GFX.CICLO
    WHERE 0=0
    ORDER BY 1
;


SELECT * FROM TMP_DET_DASH 
;

--- SUMARIZACAO SOBRE  DETALHADO DE ACORDO COM O AGRUPAMENTO DE CADA DASH

--SUMARZAR GERANDO A PIVOT SOBRE O RESULTADO ABAIXO
SELECT *
    FROM (
    SELECT DES_HOLDING, MES_REFERENCIA, UF, CICLO, 
    VLR_RESUMO, 
    NVL(LISTAGG( DES_SIT, ', ') WITHIN GROUP (ORDER BY DES_SIT ),'Pendente') DES_SIT
    FROM (
      SELECT COD_HOLDING, DES_HOLDING, MES_REFERENCIA, UF, CICLO, 
      VLR_RESUMO, DES_SIT
      FROM TMP_DET_DASH 
      GROUP BY COD_HOLDING, DES_HOLDING, MES_REFERENCIA, UF, CICLO, 
      VLR_RESUMO, DES_SIT
    --ORDER BY COD_HOLDING, DES_HOLDING, MES_REFERENCIA, UF, CICLO, VLR_RESUMO, DES_SIT
    ) X
    GROUP BY COD_HOLDING, DES_HOLDING, MES_REFERENCIA, UF, CICLO, 
    VLR_RESUMO
    ) TAB
   PIVOT (  SUM(NVL(VLR_RESUMO,0))
          FOR (DES_SIT) IN ( 'Pendente' AS "Pendente", 'Recebido' AS "Recebido", 'Aceito' AS "Aceito", 'Rejeitado' AS "Rejeitado", 'Aceito, Rejeitado' AS "Aceito + Rejeitado", 'Aceito, Recebido' AS "Aceito + Recebido", 'Recebido, Rejeitado' AS "Recebido + Rejeitado", 'Aceito, Recebido, Rejeitado' AS "Aceito + Recebido + Rejeitado" )
       ) ORDER BY 1
;



    GROUP BY
       GFX.MES_REFERENCIA,
       NVL( AF.DES_SIT, 'Pendente') --DES_SIT
    
    

;
      SELECT 
      ROW_NUMBER() OVER ( ORDER BY SOL.COD_HOLDING  ) LINHA_GFX,
      SOL.COD_HOLDING, 
      HC.DES_HOLDING, 
      SOL.MES_REFERENCIA, 
      DET.UF, 
      DET.CICLO, 
      SUM(VALOR_CONTABIL) VLR_RESUMO
      FROM SOLICITACAO_CARGA_PRE_GFX_BRT SOL
      INNER JOIN T_SIGLA_HOLDING_BRT HC ON HC.SIGLA_HOLDING = SOL.COD_HOLDING
      INNER JOIN RESUMO_FISCAL_GFX_BRT DET ON SOL.ID_CARGA = DET.ID_CARGA 
      AND SOL.TIPO_DEMONSTRATIVO = 'RESU'
      WHERE 0=0
      AND SOL.MES_REFERENCIA BETWEEN '202001' AND '202003'  
--      AND SIGLA_HOLDING in ('', 'VIV')
--      AND UF = 'MA'
--      AND NVL(CICLO,0) != 0 --IN( 1,5 )
      GROUP BY SOL.COD_HOLDING, HC.DES_HOLDING, SOL.MES_REFERENCIA
      , DET.UF
      , DET.CICLO
;

      SELECT 
      ROW_NUMBER() OVER ( ORDER BY SOL.COD_HOLDING  ) LINHA_GFX,
      SOL.COD_HOLDING, 
      HC.DES_HOLDING, 
      SOL.MES_REFERENCIA, 
      DET.UF, 
      DET.CICLO, 
      SUM(VALOR_CONTABIL) VLR_RESUMO
      FROM SOLICITACAO_CARGA_PRE_GFX_BRT SOL
      INNER JOIN T_SIGLA_HOLDING_BRT HC ON HC.SIGLA_HOLDING = SOL.COD_HOLDING
      INNER JOIN RESUMO_FISCAL_GFX_BRT DET ON SOL.ID_CARGA = DET.ID_CARGA 
      AND SOL.TIPO_DEMONSTRATIVO = 'RESU'
      WHERE 0=0
      AND VALOR_CONTABIL != 0
--      AND SOL.MES_REFERENCIA BETWEEN '202001' AND '202001'  
--      AND SIGLA_HOLDING in ('', 'VIV')
--      AND UF = 'DF'
      AND NVL(CICLO,0) != 0 --IN( 1,5 )
      AND (SOL.COD_HOLDING, 
      HC.DES_HOLDING, 
      SOL.MES_REFERENCIA, 
      DET.UF) IN (
      SELECT 
      SOL.COD_HOLDING, 
      HC.DES_HOLDING, 
      SOL.MES_REFERENCIA, 
      DET.UF
      FROM SOLICITACAO_CARGA_PRE_GFX_BRT SOL
      INNER JOIN T_SIGLA_HOLDING_BRT HC ON HC.SIGLA_HOLDING = SOL.COD_HOLDING
      INNER JOIN RESUMO_FISCAL_GFX_BRT DET ON SOL.ID_CARGA = DET.ID_CARGA 
      AND SOL.TIPO_DEMONSTRATIVO = 'RESU'
      WHERE 0=0
      AND VALOR_CONTABIL != 0
--      AND SOL.MES_REFERENCIA BETWEEN '202001' AND '202001'  
--      AND SIGLA_HOLDING in ('', 'VIV')
--      AND UF = 'DF'
      AND NVL(CICLO,0) = 0 --IN( 1,5 )
      GROUP BY SOL.COD_HOLDING, HC.DES_HOLDING, SOL.MES_REFERENCIA
      , DET.UF

      )
      GROUP BY SOL.COD_HOLDING, HC.DES_HOLDING, SOL.MES_REFERENCIA
      , DET.UF
      , DET.CICLO
ORDER BY MES_REFERENCIA DESC

