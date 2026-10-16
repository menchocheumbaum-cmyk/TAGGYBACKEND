async function notificarQr({
  db,
  enviarPushUsuario,
  usuarioId,
  mascotaId,
  nombre
}) {
  try {
    // El evento QR_SCAN ya fue guardado antes de llamar esta función.
    // Si hay más de uno en 2 minutos, evitamos mandar Push repetidos.
    const recientes = await db.query(
      `
        SELECT COUNT(*)::int AS total
        FROM eventos
        WHERE mascota_id = $1
          AND tipo = 'QR_SCAN'
          AND fecha_recepcion >=
              CURRENT_TIMESTAMP - INTERVAL '2 minutes'
      `,
      [mascotaId]
    );

    const total =
      Number(recientes.rows[0]?.total || 0);

    if (total > 1) {
      console.log(
        `[PUSH] QR omitido por cooldown: ${nombre}`
      );

      return {
        enviados: 0,
        omitida: true
      };
    }

    const resultado =
      await enviarPushUsuario(
        usuarioId,
        {
          title: "🐾 Código QR escaneado",
          body:
            `Alguien consultó el perfil público de ${nombre}.`,
          url: "/TAGGYBACKEND/"
        }
      );

    console.log(
      `[PUSH] QR escaneado: ${nombre}`
    );

    return resultado;
  } catch (error) {
    console.error(
      "Error Push QR:",
      error.message
    );

    return {
      enviados: 0,
      error: true
    };
  }
}

async function notificarAvistamiento({
  enviarPushUsuario,
  usuarioId,
  nombreMascota,
  nombreReportante,
  latitud,
  longitud
}) {
  try {
    const tieneUbicacion =
      latitud !== null &&
      latitud !== undefined &&
      longitud !== null &&
      longitud !== undefined;

    let body =
      `Se reportó un posible avistamiento de ${nombreMascota}.`;

    if (
      nombreReportante &&
      nombreReportante.trim()
    ) {
      body =
        `${nombreReportante.trim()} reportó un posible ` +
        `avistamiento de ${nombreMascota}.`;
    }

    if (tieneUbicacion) {
      body += " Incluye ubicación.";
    }

    const resultado =
      await enviarPushUsuario(
        usuarioId,
        {
          title: "🚨 Avistamiento reportado",
          body,
          url: "/TAGGYBACKEND/"
        }
      );

    console.log(
      `[PUSH] Avistamiento: ${nombreMascota}`
    );

    return resultado;
  } catch (error) {
    console.error(
      "Error Push avistamiento:",
      error.message
    );

    return {
      enviados: 0,
      error: true
    };
  }
}

module.exports = {
  notificarQr,
  notificarAvistamiento
};
