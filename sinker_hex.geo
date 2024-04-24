// Gmsh project created on Tue Nov 07 09:42:02 2023
SetFactory("OpenCASCADE");

DefineConstant[
  nelem_out = {4, Min 2, Max 20, Step 1, Name "Parameters/Mesh/# Elements, Outer"}
  nelem_in = {1, Min 2, Max 20, Step 1, Name "Parameters/Mesh/# Elements, Inner"}
  order = {1, Min 1, Max 3, Step 1, Name "Parameters/Mesh/Element Order"}
  r = {0.1, Min 0.01, Max 0.5, Step 0.01, Name "Parameters/Geometry/Sinker Radius"}
  R = {0.5, Min 0.5, Max 5, Step 0.1, Name "Parameters/Geometry/Box Radius"}
  regular = {0, Min 0, Max 1, Step 1, Name "Parameters/Geometry/Regularize Mesh"}
];


/*
     R        r
|------------|--|
*---------*-----*---------*
|   R1    |     |         |
|         |     |         |
|         |     |         |
*---------*-----*---------*
|         |     |         |
|         |     |         |
*---------*-----*---------*
|         |     |         |
|         |     |         |
|         |     |         |
*---------*-----*---------*
*/
nelem_out_real = nelem_out;
If (regular > 0)
  // Use sinker resolution for base
  nelem_out_real = nelem_in * (R - r) / (2 * r);
  If (Fabs(Round(nelem_out_real) - nelem_out_real) > 1e-6)
    Printf ("Error: Outer resolution is not an integer multiple of inner resolution\n");
    ExitAbort;
  EndIf
  nelem_out_real = Round(nelem_out_real);
EndIf
Printf ("nelem_out = %g\n", nelem_out_real);

// Define the geometry
Box(1) = {-R,-R,-R, 2*R,2*R,2*R};
Box(2) = {-R,-r,-R, 2*R,2*r,2*R};
Box(3) = {-r,-R,-R, 2*r,2*R,2*R};
Box(4) = {-R,-R,-r, 2*R,2*R,2*r};
Box(10) = {-r,-r,-r, 2*r,2*r,2*r};
BooleanFragments{ Volume{1}; Delete; }{ Volume{2,3,4,10}; } // Creates 10 (inner box) and 11 (outer box)
Coherence;

// Set num elements on corner volumes
corners() = {11, 15, 18, 20, 27, 29, 32, 36};
For i In {0:#corners()-1}
  f() = Abs(Boundary{ Volume{corners[i]}; });
  e() = Unique(Abs(Boundary{ Surface{f()}; }));
  Transfinite Curve{e()} = nelem_out_real+1;
EndFor

f() = Abs(Boundary{ Volume{10}; });
e() = Unique(Abs(Boundary{ Surface{f()}; }));
Transfinite Curve{e()} = nelem_in+1;

small_surfs() = {57, 61, 68, 105, 113, 114};
For i In {0:#small_surfs()-1}
  e() = Unique(Abs(Boundary{ Surface{small_surfs[i]}; }));
  Transfinite Curve{e()} = nelem_in+1;
EndFor
// Transfinite Surface{small_surfs()};


small_edges[] = {14, 18, 16, 20, 33, 34, 35, 36, 37, 39, 41, 43};
For i In {0:#small_edges[]-1}
  Transfinite Curve{small_edges[i]} = nelem_in+1;
EndFor


Transfinite Surface{:};
Transfinite Volume{:};

Mesh.Algorithm = 8;
Mesh.RecombinationAlgorithm = 3;
Mesh.RecombineAll = 1;
Mesh.Recombine3DAll = 1;

Mesh 3;
Mesh.ElementOrder = order;


// Faces labeled 1=z- 2=z+ 3=y- 4=y+ 5=x+ 6=x-
e = 1e-4;
zm() = Surface In BoundingBox {-R-e, -R-e, -R-e,  R+e,  R+e, -R+e};
zp() = Surface In BoundingBox {-R-e, -R-e,  R-e,  R+e,  R+e,  R+e};
ym() = Surface In BoundingBox {-R-e, -R-e, -R-e,  R+e, -R+e,  R+e};
yp() = Surface In BoundingBox {-R-e,  R-e, -R-e,  R+e,  R+e,  R+e};
xp() = Surface In BoundingBox { R-e, -R-e, -R-e,  R+e,  R+e,  R+e};
xm() = Surface In BoundingBox {-R-e, -R-e, -R-e, -R+e,  R+e,  R+e};

Physical Surface("z-", 1) = {zm()};
Physical Surface("z+", 2) = {zp()};
Physical Surface("y-", 3) = {ym()};
Physical Surface("y+", 4) = {yp()};
Physical Surface("x+", 5) = {xp()};
Physical Surface("x-", 6) = {xm()};
Physical Volume("sinker", 1) = {10};
Physical Volume ("foam", 2) = {11:36};
