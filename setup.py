from setuptools import setup, find_packages
import install_bashland
from bashland.version import __version__ as version

setup(
    name='bashland',
    version=version,
    description='Bashland python client',
    author='bashland',
    author_email='bash.land@hotmail.com',
    packages=find_packages(),
    include_package_data=True,
    install_requires=[],
)