gphoto2 --list-files | \
awk '{
  # 마지막 필드($NF)가 숫자(에포크 타임)인지 검사
  if ($NF ~ /^[0-9]+$/) {
    # date -r <숫자>를 통해 날짜/시간을 문자열로 변환 후 변수 d에 저장
    "date -r " $NF " +\"%Y-%m-%d %H:%M:%S\"" | getline d
    # 변환된 문자열(d)로 마지막 필드를 치환
    sub($NF, d)
  }
  print
}' | \
nvim -

