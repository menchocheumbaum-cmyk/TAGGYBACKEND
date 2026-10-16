function distanciaMetros(lat1, lon1, lat2, lon2) {
  const R = 6371000;
  const rad = (v) => v * Math.PI / 180;

  const dLat = rad(lat2 - lat1);
  const dLon = rad(lon2 - lon1);

  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(rad(lat1)) *
    Math.cos(rad(lat2)) *
    Math.sin(dLon / 2) ** 2;

  return 2 * R * Math.atan2(
    Math.sqrt(a),
    Math.sqrt(1 - a)
  );
}

async function prepararEsquemaGeocercaTAGGY(db) {
  await db.query(`
    CREATE TABLE IF NOT EXISTS geocercas (
      id SERIAL PRIMARY KEY,

      mascota_id INTEGER NOT NULL UNIQUE
        REFERENCES mascotas(id)
        ON DELETE CASCADE,

      nombre VARCHAR(80)
        NOT NULL
        DEFAULT 'Zona segura',

      latitud DOUBLE PRECISION NOT NULL,
      longitud DOUBLE PRECISION NOT NULL,

      radio_metros INTEGER
        NOT NULL
        DEFAULT 100,

      activa BOOLEAN
        NOT NULL
        DEFAULT TRUE,

      dentro BOOLEAN,

      fecha_ultimo_cambio TIMESTAMP,

      fecha_creacion TIMESTAMP
        NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

      fecha_actualizacion TIMESTAMP
        NOT NULL
        DEFAULT CURRENT_TIMESTAMP
    )
  `);

  console.log(
    "Esquema geocerca TAGGY listo"
  );
}

function registrarRutasGeocerca({
  app,
  db,
  verificarToken
}) {

  app.get(
    "/api/mascotas/:id/geocerca",
    verificarToken,
    async (req, res) => {
      try {
        const resultado = await db.query(
          `
            SELECT
              g.*
            FROM geocercas g

            JOIN mascotas m
              ON m.id = g.mascota_id

            WHERE g.mascota_id = $1
              AND m.usuario_id = $2
          `,
          [
            req.params.id,
            req.usuario.id
          ]
        );

        res.json({
          geocerca:
            resultado.rows[0] || null
        });

      } catch (error) {
        console.error(
          "Error consultando geocerca:",
          error
        );

        res.status(500).json({
          mensaje:
            "Error interno del servidor"
        });
      }
    }
  );


  app.put(
    "/api/mascotas/:id/geocerca",
    verificarToken,
    async (req, res) => {
      try {

        const mascotaId =
          Number(req.params.id);

        const latitud =
          Number(req.body.latitud);

        const longitud =
          Number(req.body.longitud);

        const radio =
          Number(req.body.radio_metros);

        const nombre =
          String(
            req.body.nombre ||
            "Zona segura"
          ).trim();

        if (
          !Number.isFinite(latitud) ||
          latitud < -90 ||
          latitud > 90
        ) {
          return res.status(400).json({
            mensaje:
              "Latitud invalida"
          });
        }

        if (
          !Number.isFinite(longitud) ||
          longitud < -180 ||
          longitud > 180
        ) {
          return res.status(400).json({
            mensaje:
              "Longitud invalida"
          });
        }

        if (
          !Number.isFinite(radio) ||
          radio < 25 ||
          radio > 5000
        ) {
          return res.status(400).json({
            mensaje:
              "El radio debe estar entre 25 y 5000 metros"
          });
        }

        const mascota =
          await db.query(
            `
              SELECT id, nombre
              FROM mascotas
              WHERE id = $1
                AND usuario_id = $2
            `,
            [
              mascotaId,
              req.usuario.id
            ]
          );

        if (
          mascota.rows.length === 0
        ) {
          return res.status(404).json({
            mensaje:
              "Mascota no encontrada"
          });
        }

        const resultado =
          await db.query(
            `
              INSERT INTO geocercas (
                mascota_id,
                nombre,
                latitud,
                longitud,
                radio_metros,
                activa,
                dentro
              )
              VALUES (
                $1,$2,$3,$4,$5,TRUE,NULL
              )

              ON CONFLICT (mascota_id)

              DO UPDATE SET
                nombre =
                  EXCLUDED.nombre,

                latitud =
                  EXCLUDED.latitud,

                longitud =
                  EXCLUDED.longitud,

                radio_metros =
                  EXCLUDED.radio_metros,

                activa = TRUE,
                dentro = NULL,

                fecha_actualizacion =
                  CURRENT_TIMESTAMP

              RETURNING *
            `,
            [
              mascotaId,
              nombre,
              latitud,
              longitud,
              Math.round(radio)
            ]
          );

        res.json({
          mensaje:
            "Zona segura guardada",

          geocerca:
            resultado.rows[0]
        });

      } catch (error) {
        console.error(
          "Error guardando geocerca:",
          error
        );

        res.status(500).json({
          mensaje:
            "Error interno del servidor"
        });
      }
    }
  );
}


async function evaluarGeocerca({
  db,
  enviarPushUsuario,
  mascotaId,
  latitud,
  longitud,
  precisionMetros
}) {

  const resultado = await db.query(
    `
      SELECT
        g.*,
        m.nombre AS mascota_nombre,
        m.usuario_id

      FROM geocercas g

      JOIN mascotas m
        ON m.id = g.mascota_id

      WHERE g.mascota_id = $1
        AND g.activa = TRUE
    `,
    [mascotaId]
  );

  if (
    resultado.rows.length === 0
  ) {
    return;
  }

  const g = resultado.rows[0];

  const precision =
    Number(precisionMetros);

  if (
    Number.isFinite(precision) &&
    precision > 80
  ) {
    console.log(
      "[GEOCERCA] GPS impreciso, se omite"
    );

    return;
  }

  const distancia =
    distanciaMetros(
      Number(g.latitud),
      Number(g.longitud),
      Number(latitud),
      Number(longitud)
    );

  const margen =
    Math.max(
      15,
      Number.isFinite(precision)
        ? Math.min(precision, 30)
        : 15
    );

  let dentroNuevo;

  if (g.dentro === null) {
    dentroNuevo =
      distancia <=
      Number(g.radio_metros);

  } else if (g.dentro === true) {

    dentroNuevo =
      distancia <=
      Number(g.radio_metros) +
      margen;

  } else {

    dentroNuevo =
      distancia <
      Math.max(
        0,
        Number(g.radio_metros) -
        margen
      );
  }

  if (g.dentro === null) {

    await db.query(
      `
        UPDATE geocercas
        SET
          dentro = $1,
          fecha_actualizacion =
            CURRENT_TIMESTAMP
        WHERE id = $2
      `,
      [
        dentroNuevo,
        g.id
      ]
    );

    return;
  }

  if (
    Boolean(g.dentro) ===
    dentroNuevo
  ) {
    return;
  }

  await db.query(
    `
      UPDATE geocercas
      SET
        dentro = $1,
        fecha_ultimo_cambio =
          CURRENT_TIMESTAMP,
        fecha_actualizacion =
          CURRENT_TIMESTAMP
      WHERE id = $2
    `,
    [
      dentroNuevo,
      g.id
    ]
  );

  const tipo =
    dentroNuevo
      ? "GEOCERCA_ENTRADA"
      : "GEOCERCA_SALIDA";

  await db.query(
    `
      INSERT INTO eventos (
        mascota_id,
        tipo,
        origen,
        descripcion,
        datos
      )
      VALUES (
        $1,
        $2,
        'GPS',
        $3,
        $4::jsonb
      )
    `,
    [
      mascotaId,
      tipo,

      dentroNuevo
        ? `${g.mascota_nombre} regreso a la zona segura`
        : `${g.mascota_nombre} salio de la zona segura`,

      JSON.stringify({
        distancia_metros:
          Math.round(distancia),

        radio_metros:
          g.radio_metros,

        latitud,
        longitud
      })
    ]
  );

  await enviarPushUsuario(
    g.usuario_id,
    {
      title: dentroNuevo
        ? "✅ Regreso a zona segura"
        : "🚨 Salio de la zona segura",

      body: dentroNuevo
        ? `${g.mascota_nombre} volvio a ${g.nombre}.`
        : `${g.mascota_nombre} salio de ${g.nombre}.`,

      url: "/TAGGYBACKEND/"
    }
  );

  console.log(
    `[GEOCERCA] ${g.mascota_nombre}: ` +
    `${Math.round(distancia)} m`
  );
}


module.exports = {
  prepararEsquemaGeocercaTAGGY,
  registrarRutasGeocerca,
  evaluarGeocerca
};
