/*
CREATE TABLE SCH_DW_OI (
  CSP NUMERIC(3) NOT NULL, 
  COD_HOLDING_CB CHAR(5) NULL,
  DES_HOLDING_CB VARCHAR2(35) NULL,
  UF CHAR(2) NULL,
  MESANO_REFERENCIA CHAR(6) NULL,
  CICLO NUMOBER(10) NULL, 
  DES_GRUPO_SITUACAO VARCHAR2(100) NULL,
  COD_SITUACAO NUMERIC(1) NULL,
  DES_SITUACAO VARCHAR2(100) NULL,
  VLR_TCOF NUMBER(15,5) NULL, 
  VLR_RESUMO NUMBER(15,5) NULL,
  PCT_TCOF NUMBER(15,5) NULL
)*/  
SELECT * FROM t_ctrl_arq_fiscais;
SELECT * FROM SOLICITACAO_CARGA_PRE_GFX_BRT;
SELECT * FROM RESUMO_FISCAL_GFX_BRT;
SELECT * FROM T_EMAIL_CONTROLEENVIO_BRT em WHERE em.id_seq_recepcao=264942;
SELECT * FROM T_EMAIL_CONTROLEENVIO_BRT em WHERE em.id_seq_recepcao=264945;
SELECT * FROM T_EMAIL_CONTROLEENVIO_HIST_BRT em WHERE em.id_seq_recepcao=264945;
SELECT 14 AS CSP,
           SEQ_RECEPCAO,
           DSN_RECEPCAO,
           COD_HOLDING,
           DES_HOLDING,
           UF,
           MES_REFERENCIA,
           DES_GRUPO_SITUACAO, 
           DET.COD_SITUACAO,
           DES_SITUACAO,
           nvl(VLR_TCOF,0) VLR_TCOF,
           nvl(VLR_RESUMO,0) VLR_RESUMO,
           NVL(QTD_ACIONAMENTOS,0) QTD_ACIONAMENTOS,
           CASE WHEN nvl(VLR_TCOF,0)<>nvl(VLR_RESUMO,0) THEN 'NOK' ELSE 'OK' END Status
       FROM (SELECT AF.SEQ_RECEPCAO, GFX.COD_HOLDING, GFX.DES_HOLDING,
                           GFX.UF,
                           GFX.MES_REFERENCIA MES_REFERENCIA,
                           GFX.CICLO,
                           CASE
                             WHEN GFX.VLR_RESUMO > 0          THEN 0
                             WHEN AF.DSN_RECEPCAO IS NULL     THEN 1
                             WHEN AF.COD_CRITICA2 <> 0        THEN 2
                             WHEN AF.STATUS_CRITPROT IS NULL  THEN 3
                             WHEN AF.STATUS_CRITPROT = 'FR' THEN 4
                             WHEN AF.STATUS_CRITPROT = 'FJ' THEN 5
                           END COD_SITUACAO,
                           CASE
                             WHEN GFX.VLR_RESUMO > 0          THEN 'Resumo'
                             WHEN AF.DSN_RECEPCAO IS NULL     THEN 'TCOF Não Encontrado'
                             WHEN AF.COD_CRITICA2 <> 0        THEN 'TCOF Criticado'
                             WHEN AF.STATUS_CRITPROT IS NULL  THEN 'Aguardando Protocolo'
                             WHEN AF.STATUS_CRITPROT = 'FR' THEN 'TCOF Recebido'
                             WHEN AF.STATUS_CRITPROT = 'FJ' THEN 'Mainframe Rejeitado'
                           END DES_SITUACAO,
                           GFX.NOME_REMESSA,
                           AF.DSN_RECEPCAO,
                           (SELECT COUNT(*)
                              FROM T_EMAIL_CONTROLEENVIO_BRT E
                             WHERE AF.SEQ_RECEPCAO = E.ID_SEQ_RECEPCAO) +
                           (SELECT COUNT(*)
                              FROM T_EMAIL_CONTROLEENVIO_HIST_BRT HE
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
                              FROM SOLICITACAO_CARGA_PRE_GFX_BRT SOL
                             INNER JOIN T_SIGLA_HOLDING_BRT HC    ON SOL.COD_HOLDING = HC.SIGLA_HOLDING
                             INNER JOIN RESUMO_FISCAL_GFX_BRT DET ON SOL.ID_CARGA = DET.ID_CARGA AND SOL.TIPO_DEMONSTRATIVO = 'RESU'
                             WHERE SOL.MES_REFERENCIA BETWEEN '201912' AND '201912'   
                             GROUP BY SOL.COD_HOLDING,
                                      HC.DES_HOLDING,
                                      DET.UF,
                                      SOL.MES_REFERENCIA,
                                      DET.CICLO,
                                      DET.NOME_REMESSA) GFX
                      LEFT JOIN T_CTRL_ARQ_FISCAIS_BRT AF
                        ON GFX.COD_HOLDING = AF.COD_CONTRATADA 
                           AND GFX.CICLO = AF.CICLO_NF
                       AND TO_CHAR(AF.MES_DIA_EMISSAO_NF, 'YYYYMM') = GFX.MES_REFERENCIA
                       AND AF.STATUS_RECEPCAO <> 5
                       /* AND AF.SEQ_RECEPCAO IN
                           (SELECT MAX(MAF.SEQ_RECEPCAO) SEQ_RECEPCAO
                              FROM T_CTRL_ARQ_FISCAIS_BRT MAF
                              INNER JOIN T_EMPRESA MEMPCB ON AF.COD_EOT_CB = MEMPCB.COD_EOTEMP AND MEMPCB.COD_UFEMP = GFX.UF
                              WHERE AF.COD_CONTRATADA = MAF.COD_CONTRATADA
                                    AND AF.MES_DIA_EMISSAO_NF = MAF.MES_DIA_EMISSAO_NF
                                    AND AF.CICLO_NF = MAF.CICLO_NF
                                    AND MAF.STATUS_RECEPCAO <> 5) */
                      INNER JOIN T_EMPRESA EMPCB ON AF.COD_EOT_CB = EMPCB.COD_EOTEMP AND EMPCB.COD_UFEMP = GFX.UF
                      ) DET  
                      RIGHT JOIN sch_dw_oi.t_grupo_situacao tgr ON tgr.cod_situacao = det.COD_SITUACAO  WHERE 0 = 0 AND COD_HOLDING IS NOT NULL
ORDER BY seq_recepcao
;
