async function prepararEsquemaCargaTAGGY(db) {
  await db.query(`
    ALTER TABLE dispositivos
    ADD COLUMN IF NOT EXISTS cargando BOOLEAN
    NOT NULL DEFAULT FALSE
  `);

  console.log("Esquema de carga TAGGY listo");
}

function registrarRutaEstadoCarga({
  app,
  db,
  enviarPushUsuario
}) {
  app.post(
    "/api/device/:deviceUid/status",
    async (req, res) => {
      try {
        const deviceKey =
          req.headers["x-device-key"];

        if (
          !deviceKey ||
          deviceKey !== process.env.DEVICE_API_KEY
        ) {
          return res.status(401).json({
            mensaje: "Dispositivo no autorizado"
          });
        }

        const deviceUid =
          req.params.deviceUid;

        const { charging } = req.body;

        if (typeof charging !== "boolean") {
          return res.status(400).json({
            mensaje:
              "charging debe ser true o false"
          });
        }

        const anterior = await db.query(
          `
            SELECT
              d.id,
              d.mascota_id,
              d.cargando,
              d.bateria_porcentaje,
              m.nombre AS mascota_nombre,
              m.usuario_id
            FROM dispositivos d
            JOIN mascotas m
              ON m.id = d.mascota_id
            WHERE d.device_uid = $1
              AND d.estado = 'activo'
          `,
          [deviceUid]
        );

        if (anterior.rows.length === 0) {
          return res.status(404).json({
            mensaje: "Dispositivo no encontrado"
          });
        }

        const datos = anterior.rows[0];

        const estabaCargando =
          datos.cargando === true;

        await db.query(
          `
            UPDATE dispositivos
            SET
              cargando = $1,
              ultima_conexion = CURRENT_TIMESTAMP,
              push_offline_enviado = FALSE,
              fecha_actualizacion = CURRENT_TIMESTAMP
            WHERE id = $2
          `,
          [
            charging,
            datos.id
          ]
        );

        if (estabaCargando !== charging) {
          const bateria =
            Number(datos.bateria_porcentaje);

          const bateriaTexto =
            Number.isFinite(bateria)
              ? ` Batería: ${Math.round(bateria)}%.`
              : "";

          if (charging) {
            await enviarPushUsuario(
              datos.usuario_id,
              {
                title:
                  "🔌 TAGGY conectado al cargador",
                body:
                  `El collar de ${datos.mascota_nombre} ` +
                  `comenzó a cargar.${bateriaTexto}`,
                url: "/TAGGYBACKEND/"
              }
            );
          } else {
            await enviarPushUsuario(
              datos.usuario_id,
              {
                title:
                  "🔋 Carga desconectada",
                body:
                  `El collar de ${datos.mascota_nombre} ` +
                  `dejó de cargar.${bateriaTexto}`,
                url: "/TAGGYBACKEND/"
              }
            );
          }
        }

        res.json({
          mensaje: "Estado actualizado",
          device_uid: deviceUid,
          charging
        });

      } catch (error) {
        console.error(
          "Error estado de carga:",
          error
        );

        res.status(500).json({
          mensaje: "Error interno del servidor"
        });
      }
    }
  );
}

module.exports = {
  prepararEsquemaCargaTAGGY,
  registrarRutaEstadoCarga
};
