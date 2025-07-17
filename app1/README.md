Here, we provide a script to build a Android App.

by following the steps below:

1. copy some files which will list in the script code to a dst directory. relpace all same files if exist.
2. delete exists building template files before building. like 'build', 'app/build', e.g.
3. give a option let user select the building artifact, like 'apk' or 'aab'.
4. execute different building commands based on the user selection.
    - 'apk': execute '{workdir}/gradlew assembleRelease'
    - 'aab': execute '{workdir}/gradlew bundleRelease'
5. after successfully building, copy the building artifact to a specified directory.
