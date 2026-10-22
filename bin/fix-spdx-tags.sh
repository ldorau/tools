#
# fix-spdx-tags.sh -- fix all SPDX tags
#

TAG0_C="\/\/ SPDX-License-Identifier: BSD-3-Clause"
TAG0_H="\/\* SPDX-License-Identifier: BSD-3-Clause \*\/"

TAG1_C="\/\/ SPDX-License-Identifier: BSD-3-Clause\n\/\* Copyright 2020, Intel Corporation \*\/"
TAG1_H="\/\* SPDX-License-Identifier: BSD-3-Clause \*\/\n\/\* Copyright 2020, Intel Corporation \*\/"
TAG1_WRONG="\/\*\n \* SPDX-License-Identifier: BSD-3-Clause\n \* Copyright 2020, Intel Corporation\n \*\/"

TAG2_C="\/\/ SPDX-License-Identifier: BSD-3-Clause\n\/\* Copyright 2019-2020, Intel Corporation \*\/"
TAG2_H="\/\* SPDX-License-Identifier: BSD-3-Clause \*\/\n\/\* Copyright 2019-2020, Intel Corporation \*\/"
TAG2_WRONG="\/\*\n \* SPDX-License-Identifier: BSD-3-Clause\n \* Copyright 2019-2020, Intel Corporation\n \*\/"

FILES_C=$(find -name "*.c" -o -name "*.cpp")
FILES_H=$(find -name "*.h" -o -name "*.hpp")

for file in $FILES_C; do
	sed -i "s/${TAG0_H}/${TAG0_C}/g" $file
	sed -i "N; N; N; s/${TAG1_H}/${TAG1_C}/g" $file
	sed -i "N; N; N; s/${TAG2_H}/${TAG2_C}/g" $file
	sed -i "N; N; N; s/${TAG1_WRONG}/${TAG1_C}/g" $file
	sed -i "N; N; N; s/${TAG2_WRONG}/${TAG2_C}/g" $file
done

for file in $FILES_H; do
	sed -i "s/${TAG0_C}/${TAG0_H}/g" $file
	sed -i "N; N; N; s/${TAG1_C}/${TAG1_H}/g" $file
	sed -i "N; N; N; s/${TAG2_C}/${TAG2_H}/g" $file
	sed -i "N; N; N; s/${TAG1_WRONG}/${TAG1_H}/g" $file
	sed -i "N; N; N; s/${TAG2_WRONG}/${TAG2_H}/g" $file
done
