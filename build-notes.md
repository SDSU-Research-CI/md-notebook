# Build Notes
If you are building this container, then you must first create an account with [Quantum Espresso](https://www.quantum-espresso.org/login/).

Then you will be able to [download the latest version](https://www.quantum-espresso.org/download-page/) of the source code and documentation for Quantum Espresso.

After that, you will need to extract the documentation and look for the user_guide.pdf which will contain compilation and configuration steps.

I recommend building the container up to the point that the q-e-x.x.x.tar.gz has been copied into the container.
From there, I recommend running the container and then following the compilation and configuration steps inside the container.
The QE docs should have a test suite you can run to verify the install.
Assuming that everything works well, then I would add the compilation/configuration steps to the container.
