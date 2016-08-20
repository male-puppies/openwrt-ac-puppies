提交代码，执行下面步骤：

1. 执行 修正换行符的脚本

./001-pre-commit-fix-dos2unix.sh

2. git add /path/to/file 把需要commit的加进来

3. 执行 尝试检查和修正空白字符的脚本
./002-pre-commit-check-and-tryfix-space.sh
如果这个脚本有输出，表述有需要手动修复的，请手动修复，然后回到步骤1

4. 执行 检查文件权限的脚本
./003-pre-commit-check-filemode.sh
这个脚本输出具有755权限模式的文件列表
请肉眼检查是否符合自己预期，如不符合，修改后 回到步骤1

5. git status 目测一下改动列表，没啥问题再正式commit
