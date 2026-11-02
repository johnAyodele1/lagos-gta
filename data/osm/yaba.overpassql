[out:json][timeout:60];
(
  way["highway"~"^(primary|secondary|tertiary|unclassified|residential|living_street|service|pedestrian|footway|path)$"](6.505,3.360,6.520,3.382);
  way["highway"]["bridge"](6.505,3.360,6.520,3.382);
  way["building"](6.505,3.360,6.520,3.382);
  way["barrier"](6.505,3.360,6.520,3.382);
);
out body geom;
