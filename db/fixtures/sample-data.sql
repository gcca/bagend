INSERT INTO auth_user (username, password) VALUES
  ('admin', 'changeme'),
  ('jill.valentine', 'changeme'),
  ('chris.redfield', 'changeme');

INSERT INTO home_app (name, title, description, icon, caption, link) VALUES
  ('tickets', 'Tickets', 'Gestión de solicitudes y soporte interno.', 'fa-solid fa-ticket', 'Abrir', '#'),
  ('tablero', 'Tablero', 'Indicadores comerciales y operativos.', 'fa-solid fa-chart-line', 'Ver tablero', '#'),
  ('asistencia', 'Asistencia', 'Control de asistencia del personal.', 'fa-solid fa-clipboard-check', 'Registrar', '#'),
  ('reportes', 'Reportes', 'Reportes de ventas y ocupación.', 'fa-solid fa-file-lines', 'Consultar', '#');

INSERT INTO home_userapp (username, appname) VALUES
  ('admin', 'tickets'),
  ('admin', 'tablero'),
  ('admin', 'asistencia'),
  ('admin', 'reportes'),
  ('jill.valentine', 'tickets'),
  ('jill.valentine', 'tablero'),
  ('chris.redfield', 'asistencia');
