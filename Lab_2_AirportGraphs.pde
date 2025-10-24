// Processing sketch: Air Routes Graph with Interactive Map, MST and Shortest Paths
// Place flights_final.csv in data/ folder with columns:
// Source Airport Code, Source Airport Name, Source Airport City, Source Airport Country,
// Source Airport Latitude, Source Airport Longitude,
// Destination Airport Code, Destination Airport Name, Destination Airport City, Destination Airport Country,
// Destination Airport Latitude, Destination Airport Longitude
import java.util.*;   // esto incluye Map, HashMap, ArrayList, etc.
PImage worldMap;
// --- Global state ---
Graph graph = new Graph();
boolean dataLoaded = false;

float zoom = 1.0f;
PVector offset = new PVector(0, 0);
PVector lastDrag = null;

String selectedSource = null;
String selectedTarget = null;
ArrayList<String> currentPath = new ArrayList<>();

// UI typing
boolean typingSource = false;
boolean typingTarget = false;
String bufferSource = "";
String bufferTarget = "";

String infoText = "Presiona H para ayuda.";
boolean showHelp = true;

ShortestPaths.PathResult lastSP = null;
ArrayList<Algorithms.Component> lastComponents = null;
ArrayList<MSTCompResult> lastMSTResults = null;

// Render config
float nodeRadius = 4.0f;
int nodeColor = 0xff830cc4;
int edgeColor = 0xffcccccc;
int pathColor = 0xffdc143c;
int selectedColor = 0xffff8c00;
// Calibración del mapa
float padLeft = 0;
float padRight = 0;
float padTop = 0;
float padBottom = 0;
float scaleX = 1.0;
float scaleY = 1.0;

void settings() {
  size(1280, 800);
  smooth(8);
}

void setup() {
  surface.setTitle("Rutas Aéreas - Grafo, Mapa, MST y Caminos mínimos");
  textFont(createFont("Arial", 12));
  infoText = "Presiona L para cargar CSV desde data/flights_final.csv, H para ayuda.";
  // Cargar mapa (coloca un archivo world-map.png en la carpeta data/)
  worldMap = loadImage("IMG_3277.JPG");
}

// --- Draw loop ---
void draw() {
  background(247, 255, 253);

  // Dibuja mapa con el mismo zoom/pan que el grafo
  if (worldMap != null) {
    pushMatrix();
    translate(offset.x, offset.y);
    scale(zoom);
    image(worldMap, 0, 0, width, height);
    popMatrix();
  }

  // Dibujo de aristas o camino, ya con project() alineado
  if (dataLoaded) {
    if (currentPath.size() >= 2) {
      // Solo camino mínimo
      stroke(pathColor);
      strokeWeight(3);
      for (int i = 0; i < currentPath.size() - 1; i++) {
        Airport a = graph.getAirport(currentPath.get(i));
        Airport b = graph.getAirport(currentPath.get(i+1));
        PVector p1 = project(a);
        PVector p2 = project(b);
        line(p1.x, p1.y, p2.x, p2.y);
      }
      // Nodos del camino
      noStroke();
      for (String code : currentPath) {
        Airport a = graph.getAirport(code);
        PVector pt = project(a);
        fill(selectedColor);
        ellipse(pt.x, pt.y, nodeRadius*2, nodeRadius*2);
      }
    } else {
      // Grafo completo
      stroke(edgeColor);
      strokeWeight(1);
      if (zoom >= 0.35f) {
        for (Graph.UndirectedEdge e : graph.edges) {
          Airport a = graph.getAirport(e.u);
          Airport b = graph.getAirport(e.v);
          PVector p1 = project(a);
          PVector p2 = project(b);
          //line(p1.x, p1.y, p2.x, p2.y);
        }
      } else {
        int step = 5;
        for (int i = 0; i < graph.edges.size(); i += step) {
          Graph.UndirectedEdge e = graph.edges.get(i);
          Airport a = graph.getAirport(e.u);
          Airport b = graph.getAirport(e.v);
          PVector p1 = project(a);
          PVector p2 = project(b);
          //line(p1.x, p1.y, p2.x, p2.y);
        }
      }

      noStroke();
      for (String code : graph.getCodes()) {
        Airport a = graph.getAirport(code);
        PVector pt = project(a);
        boolean sel = code.equals(selectedSource) || code.equals(selectedTarget) || currentPath.contains(code);
        fill(sel ? selectedColor : nodeColor);
        ellipse(pt.x, pt.y, nodeRadius*2, nodeRadius*2);
      }
    }
  }
  drawCalibrationOverlay();

  drawOverlay();
}


// --- Input ---
void mousePressed() {
  lastDrag = new PVector(mouseX, mouseY);
}

void mouseDragged() {
  if (lastDrag != null) {
    offset.x += mouseX - lastDrag.x;
    offset.y += mouseY - lastDrag.y;
    lastDrag.set(mouseX, mouseY);
  }
}

void mouseWheel(MouseEvent event) {
  float delta = event.getCount();
  float factor = pow(1.1f, -delta);
  zoom = constrain(zoom * factor, 0.2f, 20.0f);
}

void mouseClicked() {
  if (!dataLoaded) return;
  String hit = hitTestAirport(mouseX, mouseY);
  if (hit != null) {
    if (selectedSource == null || (selectedSource != null && selectedTarget != null)) {
      selectedSource = hit;
      selectedTarget = null;
      currentPath.clear();
      bufferSource = selectedSource;
      infoText = "Origen seleccionado: " + airportFullInfo(graph.getAirport(selectedSource));
    } else {
      selectedTarget = hit;
      bufferTarget = selectedTarget;
      infoText = "Destino seleccionado: " + airportFullInfo(graph.getAirport(selectedTarget));
    }
  }
}

void keyPressed() {
  if (key == 'h') {
    showHelp = !showHelp;
    return;
  }
  if (key == 'l') {
    loadCsvDefault();
    return;
  }
  if (key == 'c') {
    showComponents();
    return;
  }
  if (key == 'm') {
    showMSTWeights();
    return;
  }
  if (key == 'd') {
    computeShortestPath();
    return;
  }
  if (key == 'n') {
    showInfo();
    return;
  }
  if (key == 's') {
    typingSource = true;
    typingTarget = false;
    infoText = "Escribe código ORIGEN y presiona Enter: " + bufferSource;
    return;
  }
  if (key == 't') {
    typingTarget = true;
    typingSource = false;
    infoText = "Escribe código DESTINO y presiona Enter: " + bufferTarget;
    return;
  }
  if (key == 'o') {
    top10();
    return;
  }

  if (key == ENTER || key == RETURN) {
    if (typingSource) {
      selectedSource = bufferSource.trim();
      typingSource = false;
      infoText = "Origen establecido: " + selectedSource;
    } else if (typingTarget) {
      selectedTarget = bufferTarget.trim();
      typingTarget = false;
      infoText = "Destino establecido: " + selectedTarget;
    }
    return;
  }
  if (key == BACKSPACE) {
    if (typingSource && bufferSource.length() > 0) bufferSource = bufferSource.substring(0, bufferSource.length()-1);
    if (typingTarget && bufferTarget.length() > 0) bufferTarget = bufferTarget.substring(0, bufferTarget.length()-1);
    return;
  }
  // Append alfanumérico
  if (typingSource) {
    if (key != CODED) bufferSource += key;
  } else if (typingTarget) {
    if (key != CODED) bufferTarget += key;
  }

  float step = (keyEvent.isShiftDown()) ? 5 : 1;
  float sstep = (keyEvent.isShiftDown()) ? 0.02 : 0.005;

  if (key == '1') padLeft += step;
  if (key == '2') padLeft -= step;
  if (key == '3') padRight += step;
  if (key == '4') padRight -= step;
  if (key == '5') padTop += step;
  if (key == '6') padTop -= step;
  if (key == '7') padBottom += step;
  if (key == '8') padBottom -= step;

  if (key == 'x') scaleX += sstep;
  if (key == 'X') scaleX -= sstep;
  if (key == 'y') scaleY += sstep;
  if (key == 'Y') scaleY -= sstep;
}

// --- Overlay ---
void drawOverlay() {
  // Panel fondo
  fill(255, 255, 255, 220);
  noStroke();
  rect(10, 10, 520, 220);
  fill(0);
  textAlign(LEFT, TOP);

  String src = selectedSource != null ? selectedSource : "(no)";
  String dst = selectedTarget != null ? selectedTarget : "(no)";
  String typing = "";
  if (typingSource) typing = "Escribiendo ORIGEN: " + bufferSource;
  else if (typingTarget) typing = "Escribiendo DESTINO: " + bufferTarget;

  String header = "CSV cargado: " + (dataLoaded ? "Sí" : "No")
    + " | Vértices: " + (dataLoaded ? graph.size() : 0)
    + " | Aristas: " + (dataLoaded ? graph.edges.size() : 0)
    + "\nZoom: " + nf(zoom, 1, 2) + " | Pan: (" + int(offset.x) + ", " + int(offset.y) + ")"
    + "\nOrigen: " + src + " | Destino: " + dst
    + (typing.isEmpty() ? "" : "\n" + typing);

  text(header, 20, 20);

  // Info text scroll
  int boxY = 240;
  int boxH = height - boxY - 20;
  fill(255, 255, 255, 220);
  rect(10, boxY, 520, boxH);
  fill(0);
  text(infoText, 20, boxY + 10, 500, boxH - 20);

  // Help
  if (showHelp) {
    fill(255, 255, 220, 240);
    rect(width - 360, 10, 350, 240);
    fill(0);
    String help = ""
      + "Atajos:\n"
      + "- L: Cargar CSV (data/flights_final.csv)\n"
      + "- Arrastrar: Pan\n"
      + "- Rueda: Zoom\n"
      + "- N: Seleccionar nodo\n"
      + "- Clic nodo: Seleccionar origen/destino\n"
      + "- S: Escribir código ORIGEN\n"
      + "- T: Escribir código DESTINO\n"
      + "- D: Camino mínimo y Top 10 más largos\n"
      + "- O: Top 10 más caminos más largos\n"
      + "- C: Conectividad y componentes\n"
      + "- M: Peso MST por componente\n"
      + "- H: Mostrar/ocultar ayuda\n";
    text(help, width - 350, 20, 330, 220);
  }
}

// --- CSV loading ---
void loadCsvDefault() {
  String path = "flights_final.csv"; // must be in data/
  String[] lines = loadStrings(path);
  if (lines == null || lines.length <= 1) {
    infoText = "No se pudo cargar data/flights_final.csv o está vacío.";
    return;
  }
  graph = new Graph();
  // skip header
  for (int i = 1; i < lines.length; i++) {
    String line = lines[i];
    String[] cols = safeSplit(line);
    if (cols.length < 12) continue;

    String sCode = trim(cols[0]);
    String sName = trim(cols[1]);
    String sCity = trim(cols[2]);
    String sCountry = trim(cols[3]);
    double sLat = parseDouble(cols[4]);
    double sLon = parseDouble(cols[5]);

    String dCode = trim(cols[6]);
    String dName = trim(cols[7]);
    String dCity = trim(cols[8]);
    String dCountry = trim(cols[9]);
    double dLat = parseDouble(cols[10]);
    double dLon = parseDouble(cols[11]);

    if (!graph.hasAirport(sCode)) graph.addAirport(new Airport(sCode, sName, sCity, sCountry, sLat, sLon));
    if (!graph.hasAirport(dCode)) graph.addAirport(new Airport(dCode, dName, dCity, dCountry, dLat, dLon));

    double w = Haversine.distanceKm(sLat, sLon, dLat, dLon);
    graph.addUndirectedEdge(sCode, dCode, w);
  }
  dataLoaded = true;
  selectedSource = null;
  selectedTarget = null;
  currentPath.clear();
  lastSP = null;
  lastComponents = null;
  lastMSTResults = null;
  infoText = "CSV cargado. Vértices: " + graph.size() + ", Aristas: " + graph.edges.size();
}

// --- Actions ---
void showComponents() {
  if (!dataLoaded) {
    infoText = "Carga el CSV primero (L).";
    return;
  }
  lastComponents = Algorithms.connectedComponents(graph);
  StringBuilder sb = new StringBuilder();
  sb.append("¿Conexo? ").append(lastComponents.size() == 1 ? "Sí" : "No").append("\n");
  sb.append("Número de componentes: ").append(lastComponents.size()).append("\n");
  for (int i = 0; i < lastComponents.size(); i++) {
    Algorithms.Component c = lastComponents.get(i);
    sb.append("Componente ").append(i+1).append(": ").append(c.nodes.size()).append(" vértices\n");
  }
  infoText = sb.toString();
}
void showInfo() {
  if (!dataLoaded) {
    infoText = "Carga el CSV primero (L).";
    return;
  }

  if (selectedSource != null) {
    currentPath.clear();
    if (graph.getAirport(selectedSource) != null) {
      infoText = "Origen seleccionado: " + airportFullInfo(graph.getAirport(selectedSource));
    } else {
      infoText = "Seleccione/Ingrese un origen válido";
    }
  }
  if (selectedTarget != null) {
    currentPath.clear();
    if (graph.getAirport(selectedTarget) != null) {
      infoText += "\nDestino seleccionado: " + airportFullInfo(graph.getAirport(selectedTarget));
    } else {
      infoText += "\nSeleccione/Ingrese un destino válido";
    }
  }
}
void top10() {
  if (!dataLoaded) {
    infoText = "Carga el CSV primero (L).";
    return;
  }
  StringBuilder sb = new StringBuilder();
  if (selectedSource != null) {
    currentPath.clear();
    sb.append("Top 10 caminos mínimos más largos desde el origen: ");
    top10Individual(selectedSource, sb);
  }
  if (selectedTarget != null) {
    currentPath.clear();
    sb.append("Top 10 caminos mínimos más largos desde el destino: ");
    top10Individual(selectedTarget, sb);
  }
  infoText = sb.toString();
}
void top10Individual(String node, StringBuilder sb) {
  // Top 10 longest shortest paths from source
  lastSP = ShortestPaths.dijkstra(graph, node);
  ArrayList<Map.Entry<String, Double>> entries = new ArrayList<>();
  for (String code : lastSP.dist.keySet()) {
    double d = lastSP.dist.get(code);
    if (!Double.isInfinite(d)) {
      entries.add(new AbstractMap.SimpleEntry<String, Double>(code, d));
    }
  }
  entries.sort(new Comparator<Map.Entry<String, Double>>() {
    public int compare(Map.Entry<String, Double> a, Map.Entry<String, Double> b) {
      return Double.compare(b.getValue(), a.getValue());
    }
  }
  );
  int limit = min(10, entries.size());
  sb.append("\n\nDesde").append(node).append(":\n\n");
  for (int i = 0; i < limit; i++) {
    Map.Entry<String, Double> e = entries.get(i);
    Airport a = graph.getAirport(e.getKey());
    sb.append(airportInline(a))
      .append(" | ")
      .append(String.format("%.2f", e.getValue()))
      .append(" km\n");
  }
  sb.append("\n");
}
void showMSTWeights() {
  if (!dataLoaded) {
    infoText = "Carga el CSV primero (L).";
    return;
  }
  if (lastComponents == null) lastComponents = Algorithms.connectedComponents(graph);
  lastMSTResults = new ArrayList<>();
  StringBuilder sb = new StringBuilder();
  sb.append("Pesos de MST por componente:\n");
  for (int i = 0; i < lastComponents.size(); i++) {
    Algorithms.Component comp = lastComponents.get(i);
    MST.MSTResult r = MST.kruskal(graph, comp.nodes);
    lastMSTResults.add(new MSTCompResult(i+1, comp.nodes.size(), r.totalWeight));
    sb.append("Componente ").append(i+1)
      .append(" (|V|=").append(comp.nodes.size()).append("): ")
      .append(nf((float)r.totalWeight, 0, 2)).append(" km\n");
  }
  infoText = sb.toString();
}

void computeShortestPath() {
  if (!dataLoaded) {
    infoText = "Carga el CSV primero (L).";
    return;
  }
  if (selectedSource == null || selectedTarget == null) {
    infoText = "Selecciona/ingresa código de ORIGEN y DESTINO.";
    return;
  }
  if (!graph.hasAirport(selectedSource) || !graph.hasAirport(selectedTarget)) {
    infoText = "Código inválido en origen/destino.";
    return;
  }
  lastSP = ShortestPaths.dijkstra(graph, selectedSource);
  currentPath = ShortestPaths.reconstructPath(lastSP, selectedSource, selectedTarget);

  StringBuilder sb = new StringBuilder();
  Airport src = graph.getAirport(selectedSource);
  sb.append("Origen:\n").append(airportFullInfo(src)).append("\n\n");

  // Path to target
  if (currentPath.isEmpty() || !currentPath.get(0).equals(selectedSource) || !currentPath.get(currentPath.size()-1).equals(selectedTarget)) {
    sb.append("No hay camino entre ").append(selectedSource).append(" y ").append(selectedTarget).append(".\n");
  } else {
    double dist = lastSP.dist.get(selectedTarget);
    sb.append("Camino mínimo ").append(selectedSource).append(" -> ").append(selectedTarget)
      .append(" (").append(nf((float)dist, 0, 2)).append(" km").append("):\n");
    for (String code : currentPath) {
      sb.append(airportFullInfo(graph.getAirport(code))).append("\n");
    }
  }
  infoText = sb.toString();
}

// --- Helpers ---
PVector project(Airport a) {
  float lat = (float)a.lat;
  float lon = (float)a.lon;
  lat = constrain(lat, -85.05113f, 85.05113f);

  double latRad = Math.toRadians(lat);

  // Normalización Mercator
  double xNorm = (lon + 180.0) / 360.0;
  double yNorm = (1.0 - (Math.log(Math.tan(Math.PI / 4.0 + latRad / 2.0)) / Math.PI)) / 2.0;

  // Ajustes de escala correctiva
  xNorm = 0.5 + (xNorm - 0.5) * scaleX;
  yNorm = 0.5 + (yNorm - 0.5) * scaleY;

  // Aplicar padding (bordes de la imagen)
  float innerW = width - padLeft - padRight;
  float innerH = height - padTop - padBottom;

  float xCanvas = padLeft + (float)(xNorm * innerW);
  float yCanvas = padTop + (float)(yNorm * innerH);

  // Aplicar zoom/pan
  float px = xCanvas * zoom + offset.x;
  float py = yCanvas * zoom + offset.y;
  return new PVector(px, py);
}
void drawCalibrationOverlay() {
  fill(255, 240, 240, 220);
  noStroke();
  rect(width - 300, height - 120, 290, 110);
  fill(0);
  text("Calibración:\n"
    + "padLeft(1/2): " + padLeft + "  padRight(3/4): " + padRight + "\n"
    + "padTop(5/6): " + padTop + "  padBottom(7/8): " + padBottom + "\n"
    + "scaleX(x/X): " + nf(scaleX, 1, 3) + "  scaleY(y/Y): " + nf(scaleY, 1, 3),
    width - 290, height - 110);
}


String hitTestAirport(int mx, int my) {
  float r = nodeRadius + 4;
  for (String code : graph.getCodes()) {
    PVector pt = project(graph.getAirport(code));
    float dx = mx - pt.x;
    float dy = my - pt.y;
    if (dx*dx + dy*dy <= r*r) return code;
  }
  return null;
}

String airportFullInfo(Airport a) {
  if (a == null) return "(null)";
  return a.code + " | " + a.name + " | " + a.city + " | " + a.country
    + " | lat=" + nf((float)a.lat, 0, 6) + " | lon=" + nf((float)a.lon, 0, 6);
}

String airportInline(Airport a) {
  if (a == null) return "(null)";
  return a.code + " (" + a.city + ", " + a.country + ")";
}

double parseDouble(String s) {
  try {
    return Double.parseDouble(trim(s));
  }
  catch (Exception e) {
    return 0.0;
  }
}

// CSV split that handles simple quoted fields
String[] safeSplit(String line) {
  ArrayList<String> parts = new ArrayList<String>();
  StringBuilder sb = new StringBuilder();
  boolean inQuotes = false;
  for (int i = 0; i < line.length(); i++) {
    char c = line.charAt(i);
    if (c == '\"') inQuotes = !inQuotes;
    else if (c == ',' && !inQuotes) {
      parts.add(sb.toString());
      sb.setLength(0);
    } else sb.append(c);
  }
  parts.add(sb.toString());
  return parts.toArray(new String[0]);
}

// --- Data structures and algorithms (single file) ---
class Airport {
  String code, name, city, country;
  double lat, lon;
  Airport(String code, String name, String city, String country, double lat, double lon) {
    this.code = code;
    this.name = name;
    this.city = city;
    this.country = country;
    this.lat = lat;
    this.lon = lon;
  }
  public String toString() {
    return code + " - " + name + " (" + city + ", " + country + ") [" + lat + ", " + lon + "]";
  }
}

class Graph {
  HashMap<String, Airport> vertices = new HashMap<String, Airport>();
  HashMap<String, ArrayList<Edge>> adj = new HashMap<String, ArrayList<Edge>>();
  ArrayList<UndirectedEdge> edges = new ArrayList<UndirectedEdge>();

  class Edge {
    String to;
    double weight;
    Edge(String to, double w) {
      this.to = to;
      this.weight = w;
    }
  }
  class UndirectedEdge {
    String u, v;
    double weight;
    UndirectedEdge(String u, String v, double w) {
      this.u = u;
      this.v = v;
      this.weight = w;
    }
  }

  void addAirport(Airport a) {
    vertices.put(a.code, a);
    if (!adj.containsKey(a.code)) adj.put(a.code, new ArrayList<Edge>());
  }
  boolean hasAirport(String code) {
    return vertices.containsKey(code);
  }
  Airport getAirport(String code) {
    return vertices.get(code);
  }
  ArrayList<Edge> neighbors(String code) {
    ArrayList<Edge> list = adj.get(code);
    return list != null ? list : new ArrayList<Edge>();
  }
  ArrayList<UndirectedEdge> getEdges() {
    return edges;
  }
  int size() {
    return vertices.size();
  }
  java.util.Set<String> getCodes() {
    return vertices.keySet();
  }

  void addUndirectedEdge(String u, String v, double w) {
    if (!vertices.containsKey(u) || !vertices.containsKey(v) || u.equals(v)) return;
    adj.get(u).add(new Edge(v, w));
    adj.get(v).add(new Edge(u, w));
    String a = (u.compareTo(v) <= 0) ? u : v;
    String b = (u.compareTo(v) <= 0) ? v : u;
    edges.add(new UndirectedEdge(a, b, w));
  }
}

static class Haversine {
  static final double R = 6371.0;
  static double distanceKm(double lat1, double lon1, double lat2, double lon2) {
    double dLat = Math.toRadians(lat2 - lat1);
    double dLon = Math.toRadians(lon2 - lon1);
    double A = Math.sin(dLat/2.0) * Math.sin(dLat/2.0)
      + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
      * Math.sin(dLon/2.0) * Math.sin(dLon/2.0);
    double c = 2.0 * Math.atan2(Math.sqrt(A), Math.sqrt(1.0 - A));
    return R * c;
  }
}

static class Algorithms {
  static class Component {
    java.util.HashSet<String> nodes = new java.util.HashSet<String>();
  }

  static ArrayList<Component> connectedComponents(Graph g) {
    java.util.HashSet<String> visited = new java.util.HashSet<String>();
    ArrayList<Component> comps = new ArrayList<Component>();
    for (String code : g.getCodes()) {
      if (!visited.contains(code)) {
        Component c = new Component();
        java.util.ArrayDeque<String> stack = new java.util.ArrayDeque<String>();
        stack.push(code);
        visited.add(code);
        while (!stack.isEmpty()) {
          String u = stack.pop();
          c.nodes.add(u);
          for (Graph.Edge e : g.neighbors(u)) {
            if (!visited.contains(e.to)) {
              visited.add(e.to);
              stack.push(e.to);
            }
          }
        }
        comps.add(c);
      }
    }
    return comps;
  }
}

static class MST {
  static class DSU {
    java.util.HashMap<String, String> parent = new java.util.HashMap<String, String>();
    java.util.HashMap<String, Integer> rank = new java.util.HashMap<String, Integer>();
    DSU(java.util.Set<String> nodes) {
      for (String n : nodes) {
        parent.put(n, n);
        rank.put(n, 0);
      }
    }
    String find(String x) {
      String px = parent.get(x);
      if (!px.equals(x)) parent.put(x, find(px));
      return parent.get(x);
    }
    boolean union(String a, String b) {
      String ra = find(a), rb = find(b);
      if (ra.equals(rb)) return false;
      int rka = rank.get(ra), rkb = rank.get(rb);
      if (rka < rkb) parent.put(ra, rb);
      else if (rka > rkb) parent.put(rb, ra);
      else {
        parent.put(rb, ra);
        rank.put(ra, rka + 1);
      }
      return true;
    }
  }

  static class MSTResult {
    double totalWeight;
    ArrayList<Graph.UndirectedEdge> edges;
    MSTResult(double tw, ArrayList<Graph.UndirectedEdge> e) {
      totalWeight = tw;
      edges = e;
    }
  }

  static MSTResult kruskal(Graph g, java.util.Set<String> componentNodes) {
    ArrayList<Graph.UndirectedEdge> candidate = new ArrayList<Graph.UndirectedEdge>();
    java.util.HashSet<String> set = new java.util.HashSet<String>(componentNodes);
    for (Graph.UndirectedEdge e : g.getEdges()) {
      if (set.contains(e.u) && set.contains(e.v)) candidate.add(e);
    }
    candidate.sort(new java.util.Comparator<Graph.UndirectedEdge>() {
      public int compare(Graph.UndirectedEdge a, Graph.UndirectedEdge b) {
        return Double.compare(a.weight, b.weight);
      }
    }
    );

    DSU dsu = new DSU(componentNodes);
    ArrayList<Graph.UndirectedEdge> mstEdges = new ArrayList<Graph.UndirectedEdge>();
    double total = 0.0;

    for (Graph.UndirectedEdge e : candidate) {
      if (dsu.union(e.u, e.v)) {
        mstEdges.add(e);
        total += e.weight;
        if (mstEdges.size() == componentNodes.size() - 1) break;
      }
    }
    return new MSTResult(total, mstEdges);
  }
}

static class ShortestPaths {
  static class PathResult {
    java.util.HashMap<String, Double> dist = new java.util.HashMap<String, Double>();
    java.util.HashMap<String, String> prev = new java.util.HashMap<String, String>();
  }

  static PathResult dijkstra(Graph g, String source) {
    PathResult res = new PathResult();
    for (String code : g.getCodes()) {
      res.dist.put(code, Double.POSITIVE_INFINITY);
      res.prev.put(code, null);
    }
    res.dist.put(source, Double.valueOf(0.0));


    java.util.PriorityQueue<String> pq = new java.util.PriorityQueue<String>(
      11, new java.util.Comparator<String>() {
      public int compare(String a, String b) {
        return Double.compare(res.dist.get(a), res.dist.get(b));
      }
    }
    );
    pq.add(source);
    java.util.HashSet<String> visited = new java.util.HashSet<String>();

    while (!pq.isEmpty()) {
      String u = pq.poll();
      if (visited.contains(u)) continue;
      visited.add(u);

      for (Graph.Edge e : g.neighbors(u)) {
        String v = e.to;
        double alt = res.dist.get(u) + e.weight;
        if (alt < res.dist.get(v)) {
          res.dist.put(v, alt);
          res.prev.put(v, u);
          pq.add(v);
        }
      }
    }
    return res;
  }

  static ArrayList<String> reconstructPath(PathResult r, String source, String target) {
    ArrayList<String> path = new ArrayList<String>();
    if (!r.dist.containsKey(target) || Double.isInfinite(r.dist.get(target))) return path;
    String cur = target;
    while (cur != null) {
      path.add(cur);
      if (cur.equals(source)) break;
      cur = r.prev.get(cur);
    }
    java.util.Collections.reverse(path);
    return path;
  }
}

// Helper struct for MST UI summary
class MSTCompResult {
  int idx;
  int vcount;
  double totalWeight;
  MSTCompResult(int idx, int vcount, double w) {
    this.idx = idx;
    this.vcount = vcount;
    this.totalWeight = w;
  }
}
