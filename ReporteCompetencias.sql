ALTER PROCEDURE [Pyxoom].[ReporteCompetenciasGet_FF] (
	@pIdPersonaProceso int,
	@pCodigoIdioma VARCHAR(5),
	@pLlave NVARCHAR(MAX),
	@pEsCorp bit,
	@pReporteEmpresa bit,
	@pTexto AS [Pyxoom].[TextoPropiedad] READONLY
) 

AS

BEGIN
	SET NOCOUNT ON
--print CONVERT(VARCHAR, GETDATE(), 21)
	DECLARE @KEYGUID		UNIQUEIDENTIFIER
	SET @KeyGUID = KEY_GUID('ENCRYPT_KEY_CODE');
		DECLARE @query NVARCHAR(max)=N'OPEN SYMMETRIC KEY ENCRYPT_KEY_CODE DECRYPTION BY PASSWORD =';
		SET @query=@query+N''''+@pLlave+''''
		EXECUTE sp_executesql  @query

	DECLARE @vIdPersona int,
		@vIdEmpresa int,
		@vIdModelo int,
		@vIdIdioma int,
		@vIdPuesto int, @vEsPuestoPublico int,
		@vIdPerfil int,
		@vIdNivel int,
		@vIdCarpeta int,
		@vIdPersonaCatVacante int,
		@vIdCatVacante int,
		@vIdConfiguracionPsi int,
		@vFechaReporte datetime,
		@vCleaverDif1 float = 0, @vCleaverDif2 int = 0, @vCleaverDif3 int = 0, 
		@vSumaPesos decimal(5,2), @vSumaDiffPesos100 decimal(5,2),
		@vPromedioVacante decimal(5,2), @vPromedioVacanteContratados decimal(5,2),
		@vRendimiento decimal(5,2), @vRendimientoBasico decimal(5,2), @vExcedente decimal(5,2), @vClasificacion varchar(50), @vColor varchar(50), @vRGB varchar(10),
		@vSolido bit, @vPruebasPresentadas varchar(max), @vPruebasFaltantes varchar(max), @vFechaAplicacion datetime, @vClasificacionIdioma varchar(max),
		@vIdHistoriaPersonaMax int = 0,
		@vLogo varbinary(max), @vEmpresa varchar(max), @vUrlEmpresa varchar(max),
		@vPrimerNombre varchar(max), @vApellidoPaterno varchar(max), @vApellidoMaterno varchar(max), @vNombreCompleto varchar(max),
		@vFechaNacimiento varchar(max), @vPuesto varchar(max),
		@vIdEscolaridad int, @vIdInstitucion int, @vIdCarrera int, @vEscolaridad varchar(max), @vInstitucion varchar(max), @vCarrera varchar(max),
		@vTextoMale varchar(max), @vTextoFemale varchar(max), @vTextoNoData varchar(max), @vTextoNotAssigned varchar(max),
		@vParamBasicCompetence varchar(50), @vParamSelectedCompetence varchar(50), @vParamBasicCompetenceR varchar(50), @vParamSelectedCompetenceR varchar(50), 
		@vBasicCompetence bit = 0, @vSelectedCompetence bit = 0, @vAdmonTalento bit = 0,
		@vMsgCPcorto varchar(max) = '', @vIdExamenCPcorto bigint,
		@vFaceRecognition bit = 0

	DECLARE @tCleaver TABLE (percentil_valor float, valor1 int, valor2 int)
	DECLARE @tExamenPersona TABLE (r int IDENTITY(1,1), id_examen_persona bigint, id_prueba int, abreviatura varchar(10), perfilada bit, peso decimal(5,2), completada bit, sumaPeso decimal(5,2), esPlano bit, -- Examen
		ci int, clasificacion varchar(max), clasificacionIdioma varchar(max), eficiencia decimal(5,2), rendimiento decimal(5,2), fecha_contestado datetime, nombre varchar(max), receptividad int, agresividad int, aciertos int, errores int, ajuste int, -- Indicadores
		grafica varchar(max), interpretaciones varchar(max)) -- Grafica, Interpretaciones
	DECLARE @tInterp TABLE (categoria int, texto varchar(max), valor decimal(5,2), id_var_competencia int, nombre varchar(max), definicion varchar(max), idTexto bigint, idTextoNombre bigint, idTextoDefinicion bigint)
	DECLARE @tNivDes TABLE (id_nivel_desarrollo int, nombre varchar(max), id_var_competencia int, valor decimal(5,2), rango_perfil decimal(5,2))
	DECLARE @tCurso TABLE (id_curso int, id_var_competencia int, id_nivel_desarrollo int, valor decimal(5,2), rango_perfil decimal(5,2), orden int, nivelDesarrollo varchar(max), proveedor varchar(max), sede varchar(max), link varchar(max), nombre_curso varchar(max), conCurso bit)

	-- Textos y Parametros
	SELECT @vTextoMale = valor FROM @pTexto WHERE clave = 'Male'
	SELECT @vTextoFemale = valor FROM @pTexto WHERE clave = 'Female'
	SELECT @vTextoNoData = valor FROM @pTexto WHERE clave = 'NoData'
	SELECT @vTextoNotAssigned = valor FROM @pTexto WHERE clave = 'NotAssigned'

	SELECT @vParamBasicCompetence = valor FROM @pTexto WHERE clave = 'basicCompetence'
	SELECT @vParamBasicCompetenceR = valor FROM @pTexto WHERE clave = 'basicCompetenceR'
	SELECT @vParamSelectedCompetence = valor FROM @pTexto WHERE clave = 'selectedCompetence'
	SELECT @vParamSelectedCompetenceR = valor FROM @pTexto WHERE clave = 'selectedCompetenceR'

	SELECT @vEscolaridad = @vTextoNoData, @vInstitucion = @vTextoNotAssigned

	-- Seteo de información base
	SET @vFechaReporte = GETDATE()

	SELECT @vIdIdioma = id_idioma FROM PyxoomUser.Idioma_Catalogo (NOLOCK) WHERE codigo = @pCodigoIdioma

	SELECT TOP 1 @vIdPersona = pp.id_persona, @vIdEmpresa = p.id_empresa, @vIdPuesto = pp.id_puesto,
		@vIdCarpeta = pp.id_vacante, @vIdPersonaCatVacante = pp.Id_PersonaCatVacante,
		@vPrimerNombre = CASE WHEN pe.primer_nombre IS NOT NULL THEN LTRIM(CONVERT(VARCHAR(MAX), DECRYPTBYKEY(pe.primer_nombre))) ELSE '' END, 
		@vApellidoPaterno = CASE WHEN pe.apellido_paterno IS NOT NULL THEN LTRIM(CONVERT(VARCHAR(MAX), DECRYPTBYKEY(pe.apellido_paterno))) ELSE '' END, 
		@vApellidoMaterno = CASE WHEN pe.apellido_materno IS NOT NULL THEN LTRIM(CONVERT(VARCHAR(MAX), DECRYPTBYKEY(pe.apellido_materno))) ELSE '' END,
		@vFechaNacimiento = CASE WHEN pe.fecha_nacimiento IS NOT NULL THEN LTRIM(CONVERT(VARCHAR(MAX), DECRYPTBYKEY(pe.fecha_nacimiento))) ELSE '' END,
		@vIdEscolaridad = p.id_escolaridad, @vIdInstitucion = p.id_universidad, @vIdCarrera = p.id_titulo_profesional
	FROM PyxoomUser.Persona_Proceso pp (NOLOCK)
	JOIN PyxoomUser.Persona p (NOLOCK) ON pp.id_persona = p.id_persona
	JOIN Pyxoom.PersonaEncriptada pe (NOLOCK) ON p.id_persona = pe.id_persona
	WHERE pp.id_persona_proceso = @pIdPersonaProceso

	SET @vNombreCompleto = @vPrimerNombre + ' ' + @vApellidoPaterno + CASE WHEN LEN(@vApellidoMaterno) = 0 THEN '' ELSE ' ' + @vApellidoMaterno END
	SELECT @vIdCatVacante = id_CatVacante FROM Pyxoom.Persona_CatVacante (NOLOCK) WHERE Id_PersonaCatVacante = @vIdPersonaCatVacante

	IF @pEsCorp = 1
		SELECT @vIdEmpresa = ISNULL(id_empresa, @vIdEmpresa) FROM PyxoomUser.Corporativo (NOLOCK)

	SELECT @vIdModelo = id_modelo FROM PyxoomUser.Modelo WHERE id_empresa = @vIdEmpresa

	-- Configuracion de pruebas por puesto o por nivel
	IF @vIdPuesto IS NOT NULL
		SELECT @vIdPerfil = pf.id_perfil, @vIdNivel = pf.id_nivel_organizacional, @vPuesto = ISNULL(tip.texto, p.nombre), @vEsPuestoPublico = CASE WHEN p.bit_publico = 1 THEN 1 ELSE 0 END
		FROM PyxoomUser.Puesto p (NOLOCK)
		JOIN PyxoomUser.Perfil pf (NOLOCK) ON p.id_perfil = pf.id_perfil
		LEFT JOIN PyxoomUser.Texto_idioma tip (NOLOCK) ON p.id_texto = tip.id_texto AND tip.id_idioma = @vIdIdioma
		WHERE p.id_puesto = @vIdPuesto

	IF @vIdPerfil IS NOT NULL
		SELECT @vIdConfiguracionPsi = id_configuracion_psi
		FROM PyxoomUser.Perfil_Configuracion_Psi (NOLOCK)
		WHERE id_Perfil = @vIdPerfil
			AND bit_activa = 1

	IF @vIdConfiguracionPsi IS NULL AND @vIdNivel IS NOT NULL
		SELECT @vIdConfiguracionPsi = ncp.id_configuracion_psi
		FROM PyxoomUser.Empresa_Nivel_Org eno (NOLOCK)
		JOIN PyxoomUser.Nivel_Configuracion_Psi ncp (NOLOCK) ON eno.id_nivel_organizacional = ncp.id_nivel_organizacional AND eno.id_empresa = ncp.id_empresa
		WHERE eno.id_empresa = @vIdEmpresa
			AND ncp.id_nivel_organizacional = @vIdNivel
			AND ncp.bit_activa = 1

	-- Pruebas registradas por proceso de evaluacion
	INSERT INTO @tExamenPersona(id_examen_persona, id_prueba, abreviatura, perfilada, peso, completada, sumaPeso, esPlano, nombre, fecha_contestado, ci, eficiencia)
	SELECT ppe.id_examen_persona, p.id_prueba, p.abreviatura, perfilada = CASE WHEN p.abreviatura = 'P1' THEN 1 ELSE 0 END,
		peso = 0, completada = 0, sumaPeso = 0, esPlano = 0, nombre = ISNULL(tp.texto, p.descripcion), fecha_contestado = ep.fecha_contestado, 0, 0
	FROM PyxoomUser.Persona_Proceso_Examen ppe (NOLOCK)
	JOIN PyxoomUser.Examen_persona ep (NOLOCK) ON ppe.id_examen_persona = ep.id_examen_persona
	JOIN PyxoomUser.Cuestionario c (NOLOCK) ON ep.id_cuestionario = c.id_cuestionario
	JOIN PyxoomUser.Prueba p (NOLOCK) ON c.id_prueba = p.id_prueba
	LEFT JOIN PyxoomUser.Texto_idioma tp (NOLOCK) ON p.id_texto_desc = tp.id_texto AND tp.id_idioma = @vIdIdioma
	WHERE ppe.id_persona_proceso = @pIdPersonaProceso
		AND ep.completada = 1
		AND p.integral = 1
	ORDER BY p.orden


	-- Información de portada
	IF ISNULL(@vIdCarpeta, 0) = 0 AND ISNULL(@vIdCatVacante, 0) > 0
	BEGIN
		SELECT @vPromedioVacanteContratados = AVG(icom.rendimiento)
		FROM PyxoomUser.Persona_Proceso pp (NOLOCK)
        JOIN PyxoomUser.Indicadores_Competencias icom (NOLOCK) ON pp.id_persona_proceso = icom.id_persona_proceso
        JOIN PyxoomUser.Estatus_Persona ep (NOLOCK) ON pp.id_estatus_persona = ep.id_estatus
        JOIN Pyxoom.Persona_CatVacante pv (NOLOCK) on pp.Id_PersonaCatVacante = pv.Id_PersonaCatVacante
        WHERE pv.Id_CatVacante = @vIdCatVacante
           AND ep.codigo = 'CON' --Contratado
           AND icom.rendimiento != -1.00
           AND pp.id_vacante = 0
           AND ISNULL(pp.Id_PersonaCatVacante, 0) > 0

		SELECT @vPromedioVacante = AVG(icom.rendimiento)
		FROM PyxoomUser.Persona_Proceso pp (NOLOCK)
        JOIN PyxoomUser.Indicadores_Competencias icom (NOLOCK) ON pp.id_persona_proceso = icom.id_persona_proceso
        JOIN Pyxoom.Persona_CatVacante pv (NOLOCK) on pp.Id_PersonaCatVacante = pv.Id_PersonaCatVacante
        WHERE pv.Id_CatVacante = @vIdCatVacante
           AND icom.rendimiento != -1.00
		   AND icom.rendimiento IS NOT NULL
           AND pp.id_vacante = 0
           AND ISNULL(pp.Id_PersonaCatVacante, 0) > 0
	END

	SELECT @vRendimiento = rendimiento, @vRendimientoBasico = rendimientoBasico, @vExcedente = excedente, @vClasificacion = clasificacion, @vColor = color, @vRGB = rgb, @vSolido = CASE WHEN solidez = 'SI' THEN 1 ELSE 0 END
	FROM PyxoomUser.Indicadores_Competencias (NOLOCK)
	WHERE id_persona_proceso = @pIdPersonaProceso

	SELECT @vClasificacionIdioma = ISNULL(ti.texto, cc.nombre)
	FROM PyxoomUser.CatalogoClasificacion cc (NOLOCK)
	JOIN PyxoomUser.Texto_idioma ti (NOLOCK) ON cc.id_texto = ti.id_texto AND ti.id_idioma = @vIdIdioma
	WHERE cc.nombre = @vClasificacion

	SET @vPruebasPresentadas = ISNULL(STUFF((SELECT ',' + abreviatura FROM @tExamenPersona ORDER BY id_prueba ASC FOR XML PATH('')), 1, 1, ''), '')

	SET @vPruebasFaltantes = ISNULL(STUFF((
		SELECT '|' + ISNULL(ti.texto, PR.descripcion)
		FROM PyxoomUser.Nivel_Configuracion_Comp NCC (NOLOCK)
		JOIN PyxoomUser.Configuracion_Comp CC (NOLOCK) ON NCC.id_configuracion_comp = CC.id_configuracion_comp
		JOIN PyxoomUser.Configuracion_Comp_Pruebas_Necesarias CCP (NOLOCK) on CC.id_configuracion_comp = CCP.id_configuracion_comp
		JOIN PyxoomUser.Prueba PR on CCP.id_prueba = PR.id_prueba
		LEFT JOIN PyxoomUser.Texto_idioma ti ON PR.id_texto_desc = ti.id_texto AND ti.id_idioma = @vIdIdioma
		LEFT JOIN @tExamenPersona t on PR.id_prueba = t.id_prueba 
		WHERE NCC.id_nivel_organizacional = @vIdNivel AND NCC.id_empresa = @vIdEmpresa AND NCC.bit_activa = 1
		   AND CCP.id_empresa = @vIdEmpresa 
		   AND PR.abreviatura != 'P16'
		   AND t.id_prueba IS NULL
		FOR XML PATH('')), 1, 1, ''), '')

	SELECT @vFechaAplicacion = MAX(fecha_contestado) FROM @tExamenPersona

	SELECT @vIdHistoriaPersonaMax = MAX(id_historia_persona) FROM PyxoomUser.Historia_Persona (NOLOCK) WHERE id_persona = @vIdPersona

	SELECT @vLogo = logo, @vEmpresa = nombre, @vUrlEmpresa = ISNULL(url_pagina_empresa, '') FROM PyxoomUser.Empresa (NOLOCK) WHERE id_empresa = @vIdEmpresa

	SELECT @vEscolaridad = tie.texto
	FROM PyxoomUser.Escolaridad e (NOLOCK)
	LEFT JOIN PyxoomUser.Texto_idioma tie (NOLOCK) ON e.id_texto_esc = tie.id_texto AND tie.id_idioma = @vIdIdioma
	WHERE e.id_escolaridad = @vIdEscolaridad

	SELECT @vCarrera = ISNULL(tic.texto, c.descripcion)
	FROM PyxoomUser.Carreras c (NOLOCK)
	LEFT JOIN PyxoomUser.Texto_idioma tic (NOLOCK) ON c.id_texto = tic.id_texto AND tic.id_idioma = @vIdIdioma
	WHERE c.id_carrera = @vIdCarrera

	SELECT @vInstitucion = uni.nombre_universidad
	FROM PyxoomUser.Universidades uni (NOLOCK)
	WHERE uni.id_universidad = @vIdInstitucion

	SELECT @vBasicCompetence = CASE WHEN epa.valor = @vParamBasicCompetenceR THEN 1 ELSE 0 END
	FROM PyxoomUser.Parametros_Empresa pe (NOLOCK)
	JOIN PyxoomUser.Empresa_Parametros_Empresa epa (NOLOCK) ON pe.id_parametro = epa.id_parametro
	WHERE pe.nombre_parametro = @vParamBasicCompetence
		AND epa.id_empresa = @vIdEmpresa

	SELECT @vSelectedCompetence = CASE WHEN epa.valor = @vParamSelectedCompetenceR THEN 1 ELSE 0 END
	FROM PyxoomUser.Parametros_Empresa pe (NOLOCK)
	JOIN PyxoomUser.Empresa_Parametros_Empresa epa (NOLOCK) ON pe.id_parametro = epa.id_parametro
	WHERE pe.nombre_parametro = @vParamSelectedCompetence
		AND epa.id_empresa = @vIdEmpresa

	IF EXISTS (SELECT TOP 1 1 
		FROM PyxoomUser.Modulo m (NOLOCK)
        JOIN PyxoomUser.Contratos_Modulo cm (NOLOCK) on m.id_modulo = cm.id_modulo
        JOIN PyxoomUser.Contratos c (NOLOCK) on cm.id_contrato = c.id_contrato
        WHERE c.id_empresa = @vIdEmpresa
			AND m.codigo = 'ADMTL')
		SET @vAdmonTalento = 1

	SELECT @vIdExamenCPcorto = ep.id_examen_persona
	FROM PyxoomUser.Persona_Proceso_Examen ppe (NOLOCK)
	JOIN PyxoomUser.Examen_persona ep (NOLOCK) ON ppe.id_examen_persona = ep.id_examen_persona
	JOIN PyxoomUser.Cuestionario c (NOLOCK) ON ep.id_cuestionario = c.id_cuestionario
	JOIN PyxoomUser.Prueba p (NOLOCK) ON c.id_prueba = p.id_prueba
	WHERE ppe.id_persona_proceso = @pIdPersonaProceso
		AND p.abreviatura = 'P14'

	IF ISNULL(@vIdExamenCPcorto, 0) > 0 AND EXISTS (SELECT TOP 1 1 
		FROM PyxoomUser.Detalle_Competencias d (NOLOCK)
		JOIN PyxoomUser.Var_Competencias c (NOLOCK) ON d.id_var_competencia = c.id_var_competencia
		WHERE d.id_perfil = @vIdPerfil AND d.valor > 0 AND c.code IN ('comp10', 'comp28'))
	BEGIN
		IF EXISTS (SELECT 1 FROM PyxoomUser.Examen_persona e WHERE e.id_examen_persona = @vIdExamenCPcorto AND e.completada = 1)
		BEGIN
			IF (SELECT COUNT(1) FROM PyxoomUser.Respuestas_examen_persona WHERE id_examen_persona = @vIdExamenCPcorto) < 161
				SET @vMsgCPcorto = '|.\nAsí mismo Personalidad (CP) fue contestada de forma incompleta, lo cual podría impactar en la competencia de Madurez Social y Sensibilidad a Lineamientos.'
		END
		ELSE
			SET @vMsgCPcorto = 'Personalidad (CP).|' 
	END

	IF EXISTS(SELECT 1 
		FROM [Pyxoom].[ModuloHelper] (NOLOCK) 
		WHERE codigo = 'FR'
			AND CASE WHEN CONVERT(VARCHAR(MAX), DECRYPTBYKEY(estatus)) = 'activo' THEN 1 ELSE 0 END = 1
			AND CONVERT(DATETIME, CONVERT(VARCHAR(10), DECRYPTBYKEY(validez)), 103) >= CONVERT(DATETIME, CONVERT(VARCHAR(10), GETDATE(), 103), 103))
		SET @vFaceRecognition = 1

	SELECT idIdioma = @vIdIdioma,
		id_empresa = @vIdEmpresa,
		p.id_persona,
		primer_nombre = @vPrimerNombre,
        segundo_nombre = '',
        apellido_paterno = @vApellidoPaterno,
        apellido_materno = @vApellidoMaterno,
        nombre_persona = @vNombreCompleto,
        edad = [PyxoomUser].[CALCULATE_AGE](@vFechaNacimiento, @vFechaReporte),
        sexo = p.sexo,
        fecha_nacimiento = @vFechaNacimiento,
        escolaridad = @vEscolaridad,
        institucion = @vInstitucion,
        carrera = @vCarrera,
        ultima_empresa = ISNULL(p.ultima_empresa, @vTextoNoData),
        ultimo_puesto = ISNULL(p.ultimo_puesto, @vTextoNoData),
        fecha_aplicacion = @vFechaAplicacion,
		idPuesto = ISNULL(@vIdPuesto,0),
        puesto = @vPuesto,
        empresa_aplica = @vEmpresa,
        fotografia = p.fotografia,
        logo = @vLogo,
        pruebas = @vPruebasPresentadas,
		pruebasf = @vPruebasFaltantes,
		solido = @vSolido,
        rendimiento = @vRendimiento,
		rendimiento_basico = @vRendimientoBasico,
        excedente = @vExcedente,
        clasificacion = @vClasificacion,
		clasificacionIdioma = @vClasificacionIdioma,
        rgb = @vRGB,
        color = @vColor,
        promedioContratado = @vPromedioVacanteContratados,
        promedioVacante = @vPromedioVacante,
        bit_evento = CAST(0 AS BIT),
		id_nivel_organizacional = @vIdNivel,
        identificador_personal = p.identificador_personal,
		pp.bit_EvidenciaReq,
		faceRecognition = @vFaceRecognition,
		idiomas = Pyxoom.PersonaIdiomasGet(@pIdPersonaProceso, @vFechaReporte),
		muestraAdmonTalento = @vAdmonTalento,
		muestraCompetenciaBasica = @vBasicCompetence,
		muestraCompetenciaSeleccionada = @vSelectedCompetence,
		msgCpCorto = @vMsgCPcorto,
		urlEmpresa = @vUrlEmpresa,
		permanencia_esperada = Pyxoom.DescripcionPermanencia(PPFP.prediccion, @pCodigoIdioma, 2)
	FROM PyxoomUser.Persona_Proceso pp (NOLOCK)
    JOIN PyxoomUser.Persona p (NOLOCK) ON pp.id_persona = p.id_persona
    LEFT JOIN PyxoomUser.Historia_Persona hp (NOLOCK) ON p.id_persona = hp.id_persona AND @vFechaReporte BETWEEN hp.inicio_historico AND hp.fin_historico AND hp.id_historia_persona = @vIdHistoriaPersonaMax
    LEFT JOIN PyxoomUser.Historia_Puesto hpto (NOLOCK) ON pp.id_puesto = hpto.id_puesto AND hpto.id_empresa = hp.id_empresa AND @vFechaReporte BETWEEN hpto.inicio_historico AND hpto.fin_historico
	LEFT JOIN Pyxoom.PersonaProceso_FormulaPrediccion PPFP(NOLOCK) ON PPFP.id_persona_proceso = PP.id_persona_proceso
    WHERE pp.id_persona_proceso = @pIdPersonaProceso

	-- Descriptores, Requerimientos del puesto
	INSERT INTO @tInterp (categoria, texto, valor, id_var_competencia, nombre, definicion, idTexto, idTextoNombre, idTextoDefinicion)
    SELECT 0, DCS.descriptor, RES.rango_perfil, RES.id_var_competencia, vc.nombre, vc.descripcion, DCS.id_texto, vc.id_texto, vc.id_texto_desc
	FROM PyxoomUser.Resultado_Competencia_Persona_Proceso RES (NOLOCK)
	JOIN PyxoomUser.Var_Competencias vc (NOLOCK) ON RES.id_var_competencia = vc.id_var_competencia
	--JOIN PyxoomUser.Detalle_Competencias DTC (NOLOCK) ON vc.id_var_competencia = DTC.id_var_competencia
    LEFT JOIN PyxoomUser.Descriptor_Competencia DCS (NOLOCK) ON vc.id_var_competencia = DCS.id_var_competencia
		AND DCS.id_nivel_organizacional = @vIdNivel
		AND DCS.id_empresa = @vIdEmpresa
		AND ROUND(RES.rango_perfil, 0) = DCS.rango
    WHERE RES.id_persona_proceso = @pIdPersonaProceso
		--AND DTC.id_perfil = @vIdPerfil
    GROUP BY RES.id_var_competencia, DCS.descriptor, RES.rango_perfil, vc.nombre, vc.descripcion, DCS.id_texto, vc.id_texto, vc.id_texto_desc
    ORDER BY RES.rango_perfil DESC

	--CREATE INDEX IX_NOMBRE on PyxoomUser.Descriptor_Competencia (id_var_competencia,id_nivel_organizacional,id_empresa,rango,descriptor,id_texto)

	UPDATE t SET texto = ISNULL(tit.texto, t.texto), nombre = ISNULL(tin.texto, t.nombre), definicion = ISNULL(tid.texto, t.definicion)
	FROM @tInterp t
	LEFT JOIN PyxoomUser.Texto_idioma tit (NOLOCK) ON t.idTexto = tit.id_texto AND tit.id_idioma = @vIdIdioma
	LEFT JOIN PyxoomUser.Texto_idioma tin (NOLOCK) ON t.idTextoNombre = tin.id_texto AND tin.id_idioma = @vIdIdioma
	LEFT JOIN PyxoomUser.Texto_idioma tid (NOLOCK) ON t.idTextoDefinicion = tid.id_texto AND tid.id_idioma = @vIdIdioma
	
	-- Interpretaciones bajas, medias y altas
	INSERT INTO @tInterp (categoria, texto, valor, id_var_competencia)
	SELECT cat, tex, val, id_var_competencia FROM (
	SELECT cat = CASE WHEN rcpp.valor BETWEEN 3.5 AND 5.0 THEN 1 ELSE
                case when rcpp.valor BETWEEN 2.5 AND 3.499 then 2 else
                Case When rcpp.valor BETWEEN 1.0 AND 2.499 Then 3 Else 0 End end
				END,
        tex = ISNULL(ti.texto, CASE WHEN @pReporteEmpresa = 1 THEN ic.interpretacion_empresa ELSE ic.interpretacion_evaluado END),
        val = rcpp.valor,
		id_var_competencia = rcpp.id_var_competencia
	FROM PyxoomUser.Resultado_Competencia_Persona_Proceso rcpp (NOLOCK)
    JOIN PyxoomUser.Var_Competencias VCM (NOLOCK) on rcpp.id_var_competencia = VCM.id_var_competencia
    JOIN PyxoomUser.Interpretacion_Competencias ic (NOLOCK) on rcpp.id_var_competencia = ic.id_var_competencia
    JOIN PyxoomUser.Rango_Competencia rc (NOLOCK) on ic.id_rango_competencia = rc.id_rango_competencia
    JOIN PyxoomUser.Rango_Perfil_Competencia rpc (NOLOCK) on ic.id_rango_perfil_competencia = rpc.id_rango_perfil_competencia
    LEFT JOIN PyxoomUser.Texto_idioma ti (NOLOCK) ON CASE WHEN @pReporteEmpresa = 1 THEN ic.id_texto_empresa ELSE ic.id_texto_evaluado END = ti.id_texto AND ti.id_idioma = @vIdIdioma
    WHERE rcpp.id_persona_proceso = @pIdPersonaProceso
    AND ic.id_nivel_organizacional = @vIdNivel
    AND rcpp.valor BETWEEN rc.rango_inf AND rc.rango_sup
    AND rcpp.rango_perfil = rpc.perfil
    AND ic.id_empresa = @vIdEmpresa
    AND rpc.id_empresa = @vIdEmpresa
    AND rc.id_empresa = @vIdEmpresa) AS t
	ORDER BY t.cat, t.val DESC

	SELECT categoria, texto, valor, id_var_competencia, nombre, definicion FROM @tInterp
	
	-- Competencias por nivel de desarrollo
	INSERT INTO @tNivDes (id_nivel_desarrollo, nombre, id_var_competencia, valor, rango_perfil)
	SELECT  ndp.id_nivel_desarrollo,
            nivelDesarrollo = ISNULL(ti.texto, nd.nombre_nivel_desarrollo),
			rcpp.id_var_competencia,
            rcpp.valor,
            rcpp.rango_perfil
	FROM PyxoomUser.Resultado_Competencia_Persona_Proceso rcpp (NOLOCK)
	JOIN PyxoomUser.Var_Competencias vc (NOLOCK) on rcpp.id_var_competencia = vc.id_var_competencia
    JOIN PyxoomUser.Nivel_Desarrollo_Puntuacion ndp (NOLOCK) on rcpp.rango_perfil = ndp.rango_perfil
    JOIN PyxoomUser.Nivel_Desarrollo nd (NOLOCK) on ndp.id_nivel_desarrollo = nd.id_nivel_desarrollo AND nd.nombre_nivel_desarrollo != 'Capitalizar'
    LEFT JOIN PyxoomUser.Texto_idioma ti (NOLOCK) ON nd.id_texto = ti.id_texto AND ti.id_idioma = @vIdIdioma
    WHERE rcpp.id_persona_proceso = @pIdPersonaProceso
        AND nd.id_empresa = @vIdEmpresa
        AND rcpp.valor BETWEEN ndp.gap_inf AND ndp.gap_sup
    ORDER BY ndp.id_nivel_desarrollo DESC,
		rcpp.valor ASC,
		rcpp.rango_perfil DESC

	INSERT INTO @tNivDes (id_nivel_desarrollo, nombre, id_var_competencia, valor, rango_perfil)
	SELECT  ndp.id_nivel_desarrollo,
            nivelDesarrollo = ISNULL(ti.texto, nd.nombre_nivel_desarrollo),
			rcpp.id_var_competencia,
            rcpp.valor,
            rcpp.rango_perfil
	FROM PyxoomUser.Resultado_Competencia_Persona_Proceso rcpp (NOLOCK)
	JOIN PyxoomUser.Var_Competencias vc (NOLOCK) on rcpp.id_var_competencia = vc.id_var_competencia
    JOIN PyxoomUser.Nivel_Desarrollo_Puntuacion ndp (NOLOCK)  on rcpp.rango_perfil = ndp.rango_perfil
    JOIN PyxoomUser.Nivel_Desarrollo nd (NOLOCK)  on ndp.id_nivel_desarrollo = nd.id_nivel_desarrollo AND nd.nombre_nivel_desarrollo = 'Capitalizar'
    LEFT JOIN PyxoomUser.Texto_idioma ti (NOLOCK)  ON nd.id_texto = ti.id_texto AND ti.id_idioma = @vIdIdioma
    WHERE rcpp.id_persona_proceso = @pIdPersonaProceso
        AND nd.id_empresa = @vIdEmpresa
        AND rcpp.valor BETWEEN ndp.gap_inf AND ndp.gap_sup
    ORDER BY ndp.id_nivel_desarrollo DESC,
		rcpp.valor DESC,
		rcpp.rango_perfil DESC

	
	SELECT id_nivel_desarrollo, nombre, id_var_competencia, valor, rango_perfil FROM @tNivDes
	-- Recomendaciones
	SELECT DISTINCT id_var_competencia, id_nivel_desarrollo, TI.texto 
	FROM PyxoomUser.Resultado_Recomendacion_Persona_Proceso  RR
	JOIN PyxoomUser.Recomendacion_Desarrollo RD ON RR.id_recomendacion = RD.id_recomendacion
	JOIN PyxoomUser.Texto_idioma TI ON TI.id_texto = CASE WHEN @pReporteEmpresa = 0 THEN  RD.id_texto_eval ELSE RD.id_texto_emp  END AND TI.id_idioma	= @vIdIdioma
	WHERE id_persona_proceso = @pIdPersonaProceso
	ORDER BY id_nivel_desarrollo DESC
	
	
	-- Cursos y programas
	INSERT INTO @tCurso (id_curso, id_var_competencia, id_nivel_desarrollo, valor, rango_perfil, orden, nivelDesarrollo, proveedor, sede, link, nombre_curso, conCurso)
	SELECT c.id_curso, rcpp.id_var_competencia, nd.id_nivel_desarrollo, rcpp.valor, rcpp.rango_perfil, rc.orden,
		ISNULL(tind.texto, nd.nombre_nivel_desarrollo), c.proveedor, c.Sede, c.link, c.nombre_curso, conCurso = 1
	FROM PyxoomUser.Resultado_Competencia_Persona_Proceso rcpp (NOLOCK)
	JOIN PyxoomUser.Resultado_Curso_Persona_Proceso rc (NOLOCK) ON rcpp.id_persona_proceso = rc.id_persona_proceso AND rcpp.id_var_competencia = rc.id_var_competencia
	JOIN PyxoomUser.Nivel_Desarrollo nd (NOLOCK) ON rc.id_nivel_desarrollo = nd.id_nivel_desarrollo
	JOIN PyxoomUser.Curso c (NOLOCK) ON rc.id_curso = c.id_curso
	LEFT JOIN PyxoomUser.Texto_idioma tind (NOLOCK) ON nd.id_texto = tind.id_texto AND tind.id_idioma = @vIdIdioma
	WHERE rcpp.id_persona_proceso = @pIdPersonaProceso
	ORDER BY nd.id_nivel_desarrollo DESC, rc.orden ASC, rcpp.valor ASC, rcpp.rango_perfil DESC
	
	INSERT INTO @tCurso (id_curso, id_var_competencia, id_nivel_desarrollo, valor, rango_perfil, orden, nivelDesarrollo, proveedor, sede, link, nombre_curso, conCurso)
	SELECT id_curso = 0, rcpp.id_var_competencia, nd.id_nivel_desarrollo, rcpp.valor, rcpp.rango_perfil, 0,
		nombre_nivel_desarrollo = '', proveedor = '', sede = '', link = '', nombre_curso = '', conCurso = 0
	FROM PyxoomUser.Resultado_Competencia_Persona_Proceso rcpp (NOLOCK)
	JOIN PyxoomUser.Nivel_Desarrollo_Puntuacion ndp (NOLOCK) on rcpp.rango_perfil = ndp.rango_perfil
    JOIN PyxoomUser.Nivel_Desarrollo nd (NOLOCK) on ndp.id_nivel_desarrollo = nd.id_nivel_desarrollo
	LEFT JOIN @tCurso t ON rcpp.id_var_competencia = t.id_var_competencia
	WHERE rcpp.id_persona_proceso = @pIdPersonaProceso
		AND nd.id_empresa = @vIdEmpresa
		AND nd.nombre_nivel_desarrollo != 'Capitalizar'
		AND rcpp.valor BETWEEN ndp.gap_inf AND ndp.gap_sup
		AND t.id_curso IS NULL

	SELECT id_curso, id_var_competencia, id_nivel_desarrollo, valor, rango_perfil, orden, nivelDesarrollo, proveedor, sede, link, nombre_curso, conCurso FROM @tCurso
	
	-- Cursos Técnicos
	SELECT TOP 5 ct.id_curso_tecnico, ct.nombre_curso, ct.proveedor, ct.Sede, ct.link
	FROM PyxoomUser.Curso_Tecnico ct (NOLOCK)
    JOIN PyxoomUser.Resultado_Curso_Tecnico_Proceso rctp (NOLOCK) on ct.id_curso_tecnico = rctp.id_curso_tecnico
    where rctp.id_persona_proceso = @pIdPersonaProceso
	-- Grafica
	IF @pReporteEmpresa = 0 --Evaluado
	BEGIN
		SELECT rcpp.id_var_competencia,
			persona = rcpp.valor,
			perfil = ISNULL(rcpp.rango_perfil, 0),
			clave = ISNULL(rcpp.clave, 0),
			central = ISNULL(mc.bit_central, 0),
			basica = ISNULL(dc.basica, 0),
			orden = ROW_NUMBER() OVER (ORDER BY rcpp.valor DESC)
		FROM PyxoomUser.Resultado_Competencia_Persona_Proceso rcpp (NOLOCK)
		JOIN PyxoomUser.Modelo_Competencias mc (NOLOCK) ON mc.id_modelo = @vIdModelo AND rcpp.id_var_competencia = mc.id_var_competencia
		LEFT JOIN PyxoomUser.Detalle_Competencias dc (NOLOCK) ON rcpp.id_var_competencia = dc.id_var_competencia AND dc.id_perfil = @vIdPerfil
		WHERE rcpp.id_persona_proceso = @pIdPersonaProceso
		ORDER BY rcpp.valor DESC
	END
	ELSE --Empresa
	BEGIN
		SELECT rcpp.id_var_competencia,
			persona = rcpp.valor,
			perfil = ISNULL(rcpp.rango_perfil, 0),
			clave = ISNULL(rcpp.clave, 0),
			central = ISNULL(mc.bit_central, 0),
			basica = ISNULL(dc.basica, 0),
			orden = ROW_NUMBER() OVER (ORDER BY mc.bit_central DESC, mc.orden ASC)
		FROM PyxoomUser.Resultado_Competencia_Persona_Proceso rcpp (NOLOCK)
		JOIN PyxoomUser.Modelo_Competencias mc (NOLOCK) ON mc.id_modelo = @vIdModelo AND rcpp.id_var_competencia = mc.id_var_competencia
		LEFT JOIN PyxoomUser.Detalle_Competencias dc (NOLOCK) ON rcpp.id_var_competencia = dc.id_var_competencia AND dc.id_perfil = @vIdPerfil
		WHERE rcpp.id_persona_proceso = @pIdPersonaProceso
		ORDER BY mc.bit_central DESC, mc.orden ASC
	END

	SET NOCOUNT OFF
END