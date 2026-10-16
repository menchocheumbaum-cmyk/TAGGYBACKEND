let intervaloMonitor = null;

const severidadBateria = {
  normal: 0,
  baja: 1,
  critica: 2
};

function categoriaBateria(porcentaje) {
  if (porcentaje <= 10) return "critica";
  if (porcentaje <= 20) return "baja";
  return "normal";
}

function limiteOfflineSegundos(modo) {
  switch (modo) {
    case "extravio":
      return 30;

    case "mantenimiento":
      return 90;

    default:
      return 45;
  }
}

async function revisarBateria(
  db,
  enviarPushUsuario,
  dispositivo
) {
  if (
    dispositivo.bateria_porcentaje === null ||
    dispositivo.bateria_porcentaje === undefined
  ) {
    return;
  }

  const bateria =
    Number(dispositivo.bateria_porcentaje);

  if (!Number.isFinite(bateria)) {
    return;
  }

  const estadoAnterior =
    dispositivo.push_bateria_estado || "normal";

  const estadoNuevo =
    categoriaBateria(bateria);

  if (estadoAnterior === estadoNuevo) {
    return;
  }

  const empeoro =
    severidadBateria[estadoNuevo] >
    severidadBateria[estadoAnterior];

  // Si la batería se recuperó, solamente actualizamos estado.
  if (!empeoro) {
    await db.query(
      `
        UPDATE dispositivos
        SET
          push_bateria_estado = $1,
          fecha_actualizacion = CURRENT_TIMESTAMP
        WHERE id = $2
      `,
      [
        estadoNuevo,
        dispositivo.id
      ]
    );

    return;
  }

  const critica =
    estadoNuevo === "critica";

  const resultado =
    await enviarPushUsuario(
      dispositivo.usuario_id,
      {
        title: critica
          ? "🔋 Batería crítica"
          : "🔋 Batería baja",

        body:
          `El collar de ${dispositivo.mascota_nombre} ` +
          `tiene ${Math.round(bateria)}% de batería.`,

        url: "/TAGGYBACKEND/"
      }
    );

  // Solo marcamos como notificado si al menos
  // un dispositivo recibió el Push.
  if (resultado.enviados > 0) {
    await db.query(
      `
        UPDATE dispositivos
        SET
          push_bateria_estado = $1,
          fecha_actualizacion = CURRENT_TIMESTAMP
        WHERE id = $2
      `,
      [
        estadoNuevo,
        dispositivo.id
      ]
    );

    console.log(
      `[PUSH] Batería ${estadoNuevo}: ` +
      `${dispositivo.mascota_nombre} ${bateria}%`
    );
  }
}

async function revisarOffline(
  db,
  enviarPushUsuario,
  dispositivo
) {
  if (!dispositivo.ultima_conexion) {
    return;
  }

  const ultimaConexion =
    new Date(dispositivo.ultima_conexion);

  const ahora = new Date();

  const segundos =
    (ahora.getTime() -
      ultimaConexion.getTime()) / 1000;

  if (!Number.isFinite(segundos)) {
    return;
  }

  const limite =
    limiteOfflineSegundos(
      dispositivo.modo
    );

  const estaOffline =
    segundos >= limite;

  if (
    !estaOffline &&
    dispositivo.push_offline_enviado
  ) {
    await db.query(
      `
        UPDATE dispositivos
        SET
          push_offline_enviado = FALSE,
          fecha_actualizacion = CURRENT_TIMESTAMP
        WHERE id = $1
      `,
      [dispositivo.id]
    );

    return;
  }

  if (
    estaOffline &&
    !dispositivo.push_offline_enviado
  ) {
    const minutos =
      Math.floor(segundos / 60);

    const resultado =
      await enviarPushUsuario(
        dispositivo.usuario_id,
        {
          title: "📡 Collar sin conexión",

          body:
            `${dispositivo.mascota_nombre} lleva ` +
            `${minutos} minutos sin reportar ubicación.`,

          url: "/TAGGYBACKEND/"
        }
      );

    if (resultado.enviados > 0) {
      await db.query(
        `
          UPDATE dispositivos
          SET
            push_offline_enviado = TRUE,
            fecha_actualizacion = CURRENT_TIMESTAMP
          WHERE id = $1
        `,
        [dispositivo.id]
      );

      console.log(
        `[PUSH] Offline: ` +
        `${dispositivo.mascota_nombre} ` +
        `${minutos} min`
      );
    }
  }
}

function iniciarMonitorAlertas({
  db,
  enviarPushUsuario
}) {
  if (intervaloMonitor) {
    return;
  }

  let ejecutando = false;

  async function revisar() {
    if (ejecutando) {
      return;
    }

    ejecutando = true;

    try {
      const resultado =
        await db.query(
          `
            SELECT
              d.id,
              d.device_uid,
              d.modo,
              d.bateria_porcentaje,
              d.ultima_conexion,
              d.push_bateria_estado,
              d.push_offline_enviado,

              m.id AS mascota_id,
              m.nombre AS mascota_nombre,
              m.usuario_id

            FROM dispositivos d

            JOIN mascotas m
              ON m.id = d.mascota_id

            WHERE d.estado = 'activo'
          `
        );

      for (
        const dispositivo
        of resultado.rows
      ) {
        await revisarBateria(
          db,
          enviarPushUsuario,
          dispositivo
        );

        await revisarOffline(
          db,
          enviarPushUsuario,
          dispositivo
        );
      }
    } catch (error) {
      console.error(
        "Error monitor alertas TAGGY:",
        error
      );
    } finally {
      ejecutando = false;
    }
  }

  // Revisar inmediatamente al iniciar Render.
  revisar();

  // Después, cada minuto.
  intervaloMonitor =
    setInterval(
      revisar,
      5 * 1000
    );

  if (intervaloMonitor.unref) {
    intervaloMonitor.unref();
  }

  console.log(
    "Monitor automático TAGGY iniciado"
  );
}

module.exports = {
  iniciarMonitorAlertas
};
