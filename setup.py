from setuptools import setup, find_packages
import install_bashland
from bashland.version import __version__ as version

exec (open('bashland/version.py').read())

setup(
    name='bashland',
    version=version,
    description='Bashland python client',
    author='bashland',
    author_email='bash.land@hotmail.com',
    packages=find_packages(),
    include_package_data=True,
    install_requires=[
        'requests==2.23.0', 'jsonpickle==3.0.1', 'click==6.7',
        'npyscreen==4.10.5', 'python-dateutil==2.8.1',
        'pymongo==3.10.1', 'inflection==0.3.1', 'humanize==1.0.0',
        'future==0.18.3', 'mock==3.0.5'
    ],
    entry_points={
        'console_scripts': ['bl=bashland.bl:main',
                            'bashland=bashland.bashland:main']
    },
)