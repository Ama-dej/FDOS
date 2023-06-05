[BITS 16]
[ORG 0x0000]

	MOV AH, 0x05
	MOV BX, BUFFER
	MOV SI, FILENAME
	MOV CX, 5
	MOV DX, 1
	INT 0x80

	MOV AH, 0x00
	INT 0x80

FILENAME: DB "TEST.TXT", 0x00
BUFFER:
DB "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Urna nec tincidunt praesent semper feugiat nibh sed pulvinar. Eget est lorem ipsum dolor. Ut consequat semper viverra nam libero justo laoreet sit. Vitae tempus quam pellentesque nec. Vel quam elementum pulvinar etiam. Sapien faucibus et molestie ac. Adipiscing elit ut aliquam purus sit amet. Sit amet luctus venenatis lectus magna fringilla urna porttitor. Praesent elementum facilisis leo vel fringilla est ullamcorper eget. Nulla malesuada pellentesque elit eget. Aliquet nibh praesent tristique magna sit. Scelerisque fermentum dui faucibus in ornare quam viverra orci. Dui id ornare arcu odio ut sem nulla pharetra. Nullam non nisi est sit. Sed tempus urna et pharetra pharetra massa massa ultricies mi. Egestas sed sed risus pretium quam vulputate dignissim. Faucibus pulvinar elementum integer enim neque volutpat ac tincidunt. Ut sem viverra aliquet eget sit. Feugiat sed lectus vestibulum mattis ullamcorper. Congue eu consequat ac felis donec et odio pellentesque. Donec et odio pellentesque diam volutpat commodo sed egestas egestas. Non blandit massa enim nec dui nunc mattis enim. Aliquet sagittis id consectetur purus ut. Fringilla phasellus faucibus scelerisque eleifend donec pretium vulputate sapien. Netus et malesuada fames ac turpis. Tempus urna et pharetra pharetra massa massa ultricies. In pellentesque massa placerat duis ultricies lacus sed turpis. Cras ornare arcu dui vivamus arcu felis bibendum. Egestas fringilla phasellus faucibus scelerisque eleifend donec pretium vulputate. In mollis nunc sed id semper risus. Sollicitudin ac orci phasellus egestas. Purus sit amet volutpat consequat mauris nunc congue nisi vitae. Ipsum nunc aliquet bibendum enim facilisis. Lobortis feugiat vivamus at augue eget arcu dictum varius. Tempor nec feugiat nisl pretium fusce id. Vel eros donec ac odio tempor. Tempus quam pellentesque nec nam aliquam sem et tortor consequat. Massa massa ultricies mi quis hendrerit dolor magna eget est. Dolor sed viverra ipsum nunc aliquet bibendum enim facilisis. Eu augue ut lectus arcu bibendum at varius vel pharetra. Augue eget arcu dictum varius duis at. Odio aenean sed adipiscing diam donec adipiscing. Commodo odio aenean sed adipiscing. Faucibus in ornare quam viverra orci sagittis eu. Mi sit amet mauris commodo quis imperdiet massa tincidunt nunc."
