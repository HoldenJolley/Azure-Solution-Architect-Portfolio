const navItems = document.querySelectorAll('.nav-item[href^="#"]');
const sections = [...document.querySelectorAll('main section[id]')];
const observer = new IntersectionObserver(entries => {
  entries.forEach(entry => {
    if (!entry.isIntersecting) return;
    navItems.forEach(item => item.classList.toggle('active', item.getAttribute('href') === '#' + entry.target.id));
  });
}, {rootMargin: '-25% 0px -65% 0px', threshold: 0});
sections.forEach(section => observer.observe(section));
