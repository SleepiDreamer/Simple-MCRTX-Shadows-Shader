# Simple MCRTX Shadows Shader
 An example MCRTX shader supporting basic ray-traced sun shadows. The purpose of this example
 isn't necessarily to be used as a direct reference, but to demonstrate the implementation of
 simple features in the RTX pipeline.

## Implemented Features:
 ### G-Buffers:
  The primary ray traversal pass populates a few g-buffers with versatile information about
  the scene within view. Data like surface albedo, PBR values, geoemetry normals, and motion
  vectors are included.

 ### Sun Shadows:
  Shadows cast by objects blocking the sunlight are rendered with pixel-perfect accuracy, 
  With one ray per pixel sent towards the sun to test if any intersections occur. Sunlight
  intensity is stylistically faded as faces turn away from the sun direction.

 ### Auto Exposure:
  Output values outside of the range [0, 1] are supported, so auto exposure has been
  implemented to account for scenes that are generally too bright or dark for rendering 
  on screen.

## Building the Example:
 The example was created and developed on VS Code, and includes a build task configuration
 that calls lazurite to compile and export the project. You'll need to add lazurite to your
 PATH if you want to take advantage of this, which can be done by adding the following entry
 to PATH*:
 `%localappdata%\Packages\PythonSoftwareFoundation.Python.3.12_qbz5n2kfra8p0\LocalCache\local-packages\Python312\Scripts`. 
 
  \* The entry may look different for different istallations of Python, or if you haven't
  installed lazurite through pip.

## Remarks:
 My hope is for this example to provide a good introduction to MCRTX shader development that
 can serve to kick-start your experience building shaders in the pipeline. The unique
 capability to take advantage of hardware-accelerated ray tracing serves to enable the 
 creation of many real-time realistic lighting effects that wouldn't be possible otherwise.
 
 Be sure to leave any feedback you have here, or contact me through the various social platforms I'm on. Thanks for using this example!