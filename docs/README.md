Magik
=====

### Purpose & design

Magik is a high performance spectral path tracer API for rendering arbitrary 3D scenes in the framework of the general theory of relativity. 

It is designed to prioritize physical accuracy by default and integrate into VFX workflows using industry standard features, such as AOVs. Magik is capable of simulating a wide range of physical effects to a high degree of accuracy but does not force the user to adhere to the strictest standards.

### Features
* **Multiple metrics:** Scenes can dynamically switch between rendering in the Minkowski, Schwarzschild and Kerr spacetime. 
* **Intrinsic relativistic effects:** Phenomena such as redshift, light travel delay, gravitational lensing and aberration of light occur naturally, including for user-provided assets such as RGB textures.
* **Togglable realism:** Where possible Magik provides the user with options to chose between various degrees of realism for specific effects to accomidate the requierements of their specific scene. For instance, the polarization of light might be assumed to be constant, change classically or relativistically.
* **Adaptive runge kutta:** Null-geodesics are traced through the 3D scene using the Runge-Kutta-Fehlberg 45 (RKF45) method for non-trivial metrics ensuring a user chosen bounded error in the solution.
* **Physical Units:** Magik uses SI-base units for all user-exposed options.
* **Full spectral pipeline:** The path integration occurs in the spectral domain. This approach was chosen for its natural compliance with general relativity, improved colour accuracy and elimination of conventional tristimulus rendering artifacts.
* **Unbiased:** It is an unbiased path tracer.
* **Material system:** Magik uses a custom build material system, the *bxdf*. The system loosely follows the guiding principles of [OpenPBR](https://academysoftwarefoundation.github.io/OpenPBR/). A custom solution was designed due to the unique challenges involved in evaluating materials in both a spectral and relativistic context. It provides the user with the ability to create node graphs and arbitrarily layered materials. The bxdf takes full advantage of the renderers spectral nature and provides the entire [RefractiveIndex.INFO](https://refractiveindex.info/) dataset as ready to use materials based on real world measurement data.
* **Lens simulation:** The renderer provides a built-in solution for simulating optical systems and rendering scenes through them to produce physical artifacts such as chromatic aberration and aberrations. It supports spherical, aspherical and anamorphic optics. The entire [Optical Bench Hub](https://www.photonstophotos.net/GeneralTopics/Lenses/OpticalBench/OpticalBenchHub.htm) dataset and dozens of additional lenses are provided.    

### Usage
**Magik cannot be build as a standalone application !** The API provides opaque functions and a command queue system for developers to built an integration layer for their DCCs. It is designed to work natively with Windows or Linux and requieres a Nvidia GPU. 

### Gallery

### Demo

License
-------

Magik is licensed under the PolyForm Small Business License 1.0.0, see [LICENSE.txt](https://github.com/ErikHall1801/Magik/blob/main/LICENSE.txt) for more information.
